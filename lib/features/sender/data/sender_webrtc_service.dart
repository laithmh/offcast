import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/models/signaling_message.dart';
import '../../../core/network/discovery_beacon.dart';
import '../../../core/network/local_udp_relay.dart';
import '../../../core/services/foreground_service_helper.dart';

enum SenderConnectionState {
  disconnected,
  capturingScreen,
  connectingSignaling,
  connectedSignaling,
  negotiatingWebRTC,
  streaming,
  failed,
}

class SenderWebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  final LocalUdpRelay _udpRelay = LocalUdpRelay();

  final StreamController<SenderConnectionState> _stateController =
      StreamController<SenderConnectionState>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<StreamPerformanceStats> _statsController =
      StreamController<StreamPerformanceStats>.broadcast();
  final StreamController<SignalingMessage> _prompterMessageController =
      StreamController<SignalingMessage>.broadcast();

  Stream<SenderConnectionState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<StreamPerformanceStats> get statsStream => _statsController.stream;
  Stream<SignalingMessage> get prompterMessageStream =>
      _prompterMessageController.stream;

  final List<RTCIceCandidate> _iceCandidateQueue = [];
  bool _hasRemoteDescription = false;
  String? _currentTargetHost;
  StreamingQualityPreset _currentPreset = StreamingQualityPreset.performance540p60;
  CodecEngine _codecEngine = CodecEngine.vp8;
  StreamSourceType _currentStreamSource = StreamSourceType.screen;
  CameraFacingMode _currentCameraFacing = CameraFacingMode.environment;
  Timer? _statsTimer;
  int _lastBytesSent = 0;
  int _lastFramesEncoded = 0;
  DateTime? _lastStatsTime;

  StreamSourceType get currentStreamSource => _currentStreamSource;
  CameraFacingMode get currentCameraFacing => _currentCameraFacing;

  /// Starts the ultra-low latency screen mirroring or direct studio camera stream
  Future<void> startMirroring({
    required String host,
    int port = WebRTCConstants.signalingPort,
    StreamingQualityPreset preset = StreamingQualityPreset.performance540p60,
    CodecEngine codecEngine = CodecEngine.vp8,
    StreamSourceType streamSource = StreamSourceType.screen,
    CameraFacingMode cameraFacing = CameraFacingMode.environment,
  }) async {
    _currentTargetHost = host;
    _currentPreset = preset;
    _codecEngine = codecEngine;
    _currentStreamSource = streamSource;
    _currentCameraFacing = cameraFacing;
    _iceCandidateQueue.clear();
    _hasRemoteDescription = false;

    try {
      // 1. Start Native Android Foreground Service for persistent projection
      _stateController.add(SenderConnectionState.capturingScreen);
      await ForegroundServiceHelper.startService();

      // 2. Keep screen on
      await ForegroundServiceHelper.setKeepScreenOn(true);

      // 3. Acquire Media (Direct Studio Camera or Display Media)
      if (streamSource == StreamSourceType.studioCamera) {
        _localStream = await navigator.mediaDevices.getUserMedia(
          WebRTCConstants.getCameraMediaConstraints(
            preset: preset,
            facing: cameraFacing,
          ),
        );
      } else {
        _localStream = await navigator.mediaDevices.getDisplayMedia(
          WebRTCConstants.getDisplayMediaConstraints(preset: preset),
        );
      }

      final videoTracks = _localStream?.getVideoTracks() ?? [];
      if (videoTracks.isEmpty) {
        throw Exception(
          streamSource == StreamSourceType.studioCamera
              ? 'No camera video track obtained.'
              : 'No display video track obtained.',
        );
      }

      // 4. Bind process to Wi-Fi network interface
      await ForegroundServiceHelper.bindToWifiNetwork();

      // 5. Connect to Receiver Embedded Signaling Server via WebSocket
      _stateController.add(SenderConnectionState.connectingSignaling);
      final wsUrl = Uri.parse('ws://$host:$port');
      debugPrint('[SenderWebRTC] Connecting to signaling server at $wsUrl');

      final ws = await WebSocket.connect(
        wsUrl.toString(),
      ).timeout(const Duration(seconds: 5));
      _channel = IOWebSocketChannel(ws);
      _stateController.add(SenderConnectionState.connectedSignaling);

      // 6. Listen for incoming signaling messages
      _channelSubscription = _channel!.stream.listen(
        _handleSignalingMessage,
        onError: (error) {
          debugPrint('[SenderWebRTC] Signaling channel error: $error');
          _errorController.add('Signaling connection error: $error');
          _stateController.add(SenderConnectionState.failed);
        },
        onDone: () {
          debugPrint('[SenderWebRTC] WebSocket disconnected.');
          if (_peerConnection != null) {
            _stateController.add(SenderConnectionState.disconnected);
          }
        },
      );

      // 7. Create WebRTC Peer Connection
      _stateController.add(SenderConnectionState.negotiatingWebRTC);
      _peerConnection = await createPeerConnection(
        WebRTCConstants.rtcConfiguration,
      );

      _peerConnection!.onSignalingState = (RTCSignalingState state) {
        debugPrint('[SenderWebRTC] Signaling State: $state');
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('[SenderWebRTC] ICE Connection State: $state');
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[SenderWebRTC] PeerConnection Connection State: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _stateController.add(SenderConnectionState.streaming);
          _startStatsPolling();
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _stateController.add(SenderConnectionState.failed);
          _stopStatsPolling();
        }
      };

      bool hasPhysicalCandidate = false;

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          debugPrint('[SenderWebRTC] Raw onIceCandidate generated: ${candidate.candidate}');
          final myIp =
              await NetworkHelper.findBestMatchingLocalIp(_currentTargetHost) ??
                  await NetworkHelper.getMyDeviceIp();

          var candStr = candidate.candidate!;
          final isPhysical = !candStr.contains('127.0.0.1') &&
              !candStr.contains('::1') &&
              !candStr.contains('localhost');

          if (isPhysical) {
            hasPhysicalCandidate = true;
            // Physical native candidate available: ensure relay is stopped
            if (_udpRelay.publicPort != null) {
              await _udpRelay.stop();
            }
          }

          // Only use relay if no physical interface exists
          final loopbackUdpMatch = RegExp(r'candidate:\S+ \d+ udp \d+ 127\.0\.0\.1 (\d+)').firstMatch(candStr);
          if (loopbackUdpMatch != null && !hasPhysicalCandidate) {
            final loopbackPort = int.tryParse(loopbackUdpMatch.group(1)!);
            if (loopbackPort != null) {
              final relayPort = await _udpRelay.start(
                targetLoopbackPort: loopbackPort,
                remotePeerIp: _currentTargetHost,
              );
              candStr = candStr.replaceAll('127.0.0.1 $loopbackPort', '$myIp $relayPort');
            }
          }

          final fixedCandStr = SdpCandidateSanitizer.sanitizeCandidate(
            candStr,
            myIp,
          );
          if (fixedCandStr != null) {
            debugPrint('[SenderWebRTC] Local ICE Candidate generated: $fixedCandStr');
            final fixedCandidate = RTCIceCandidate(
              fixedCandStr,
              candidate.sdpMid,
              candidate.sdpMLineIndex,
            );
            _sendSignalingMessage(SignalingMessage.candidate(fixedCandidate));
          }
        }
      };

      // 8. Add tracks to Peer Connection
      for (final track in videoTracks) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // 9. Register ICE gathering listener before setting local description
      final gatheringCompleter = Completer<void>();
      _peerConnection!.onIceGatheringState = (state) {
        debugPrint('[SenderWebRTC] ICE Gathering State: $state');
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          if (!gatheringCompleter.isCompleted) gatheringCompleter.complete();
        }
      };

      // 10. Generate SDP Offer & Set Local Description
      final offer = await _peerConnection!.createOffer(
        WebRTCConstants.senderOfferConstraints,
      );
      await _peerConnection!.setLocalDescription(offer);

      // Force high bitrate encodings and maintain framerate on video senders
      try {
        final senders = await _peerConnection!.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            final parameters = sender.parameters;
            parameters.degradationPreference =
                RTCDegradationPreference.BALANCED;
            if (parameters.encodings != null &&
                parameters.encodings!.isNotEmpty) {
              final scaleDown = preset == StreamingQualityPreset.performance540p60
                  ? 2.0
                  : (preset == StreamingQualityPreset.ultra1080p30 ? 1.0 : 1.5);
              for (final encoding in parameters.encodings!) {
                encoding.minBitrate = (preset.bitrateKbps * 0.7).toInt() * 1000;
                encoding.maxBitrate = preset.bitrateKbps * 1000;
                encoding.maxFramerate = preset.targetFps;
                encoding.scaleResolutionDownBy = scaleDown;
              }
            }
            await sender.setParameters(parameters);
          }
        }
      } catch (_) {}

      // Wait for host ICE candidates to be gathered into SDP
      await Future.any([
        gatheringCompleter.future,
        Future.delayed(const Duration(milliseconds: 1000)),
      ]);

      final fullOffer = await _peerConnection!.getLocalDescription();
      final myIp =
          await NetworkHelper.findBestMatchingLocalIp(_currentTargetHost) ??
              await NetworkHelper.getMyDeviceIp();
      var sdpStr = SdpCandidateSanitizer.sanitizeSdp(
        fullOffer?.sdp ?? offer.sdp,
        myIp,
        bitrateKbps: preset.bitrateKbps,
        codecEngine: _codecEngine,
      );

      if (!hasPhysicalCandidate && _udpRelay.publicPort != null) {
        sdpStr = sdpStr.replaceAllMapped(
          RegExp(r'm=video \d+ (UDP/TLS/RTP/SAVPF)'),
          (m) => 'm=video ${_udpRelay.publicPort} ${m.group(1)}',
        );
      }

      debugPrint('[SenderWebRTC] >>> OUTGOING SDP OFFER:\n$sdpStr');
      _sendSignalingMessage(SignalingMessage.offer(sdpStr));
    } catch (e, stack) {
      debugPrint('[SenderWebRTC] Error starting mirroring: $e\n$stack');
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || errorStr.contains('111')) {
        _errorController.add(
          'Target found at $host:$port, but Receiver Mode is not running. Please open Receiver Mode on the display device.',
        );
      } else if (errorStr.contains('Network is unreachable') || errorStr.contains('101')) {
        _errorController.add(
          'Wi-Fi disconnected. Please connect this device to the Receiver’s Wi-Fi Hotspot.',
        );
      } else if (errorStr.contains('No route to host') || errorStr.contains('113')) {
        _errorController.add(
          'Cannot reach $host:$port. Ensure 4G Mobile Data is turned OFF and both devices are connected to the same Hotspot.',
        );
      } else if (e is TimeoutException) {
        _errorController.add(
          'Connection to $host:$port timed out. Ensure Receiver Mode is running and IP matches the display screen.',
        );
      } else {
        _errorController.add('Failed to start mirroring: $e');
      }
      _stateController.add(SenderConnectionState.failed);
      await stopMirroring();
    }
  }

  void _sendSignalingMessage(SignalingMessage message) {
    if (_channel != null) {
      final encoded = jsonEncode(message.toJson());
      _channel!.sink.add(encoded);
    }
  }

  Future<void> _handleSignalingMessage(dynamic rawMessage) async {
    try {
      final json = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final message = SignalingMessage.fromJson(json);

      switch (message.type) {
        case 'answer':
          if (message.sdp != null) {
            debugPrint(
              '[SenderWebRTC] Received SDP Answer. Sanitizing & setting remote description...',
            );
            final answerSdp = SdpCandidateSanitizer.sanitizeSdp(
              message.sdp,
              _currentTargetHost,
              codecEngine: _codecEngine,
            );
            debugPrint('[SenderWebRTC] <<< INCOMING SDP ANSWER:\n$answerSdp');
            final description = RTCSessionDescription(answerSdp, 'answer');
            await _peerConnection!.setRemoteDescription(description);
            _hasRemoteDescription = true;

            // Apply active encoder bitrate and framerate parameters once negotiation finishes
            try {
              final senders = await _peerConnection!.getSenders();
              for (final sender in senders) {
                if (sender.track?.kind == 'video') {
                  final parameters = sender.parameters;
                  parameters.degradationPreference =
                      RTCDegradationPreference.BALANCED;
                  if (parameters.encodings != null &&
                      parameters.encodings!.isNotEmpty) {
                    final scaleDown = _currentPreset ==
                            StreamingQualityPreset.performance540p60
                        ? 2.0
                        : (_currentPreset == StreamingQualityPreset.ultra1080p30
                            ? 1.0
                            : 1.5);
                    for (final encoding in parameters.encodings!) {
                      encoding.maxBitrate = _currentPreset.bitrateKbps * 1000;
                      encoding.minBitrate =
                          (_currentPreset.bitrateKbps * 0.70).toInt() * 1000;
                      encoding.maxFramerate = _currentPreset.targetFps;
                      encoding.scaleResolutionDownBy = scaleDown;
                    }
                  }
                  await sender.setParameters(parameters);
                  debugPrint(
                    '[SenderWebRTC] Successfully configured active encoder: maxBitrate=${_currentPreset.bitrateKbps}kbps, minBitrate=${(_currentPreset.bitrateKbps * 0.70).toInt()}kbps, maxFps=${_currentPreset.targetFps}',
                  );
                }
              }
            } catch (e) {
              debugPrint('[SenderWebRTC] Note: Could not set post-answer sender parameters: $e');
            }

            // Drain queued ICE candidates
            final queued = List<RTCIceCandidate>.from(_iceCandidateQueue);
            _iceCandidateQueue.clear();
            for (final candidate in queued) {
              debugPrint(
                '[SenderWebRTC] Adding queued remote ICE candidate: ${candidate.candidate}',
              );
              try {
                await _peerConnection!.addCandidate(candidate);
              } catch (e) {
                debugPrint('[SenderWebRTC] Error adding remote candidate: $e');
              }
            }

            _stateController.add(SenderConnectionState.streaming);
          }
          break;

        case 'candidate':
          if (message.candidate != null) {
            final candidateData = message.candidate!;
            final candStr = candidateData['candidate'] as String?;
            final fixedCandStr = SdpCandidateSanitizer.sanitizeCandidate(
              candStr,
              _currentTargetHost,
            );

            if (fixedCandStr != null) {
              final sdpMid = candidateData['sdpMid'] as String? ?? '0';
              final sdpMLineIndex = candidateData['sdpMLineIndex'] as int? ?? 0;
              final iceCandidate = RTCIceCandidate(
                fixedCandStr,
                sdpMid,
                sdpMLineIndex,
              );

              if (_hasRemoteDescription && _peerConnection != null) {
                debugPrint(
                  '[SenderWebRTC] Adding direct remote ICE candidate: $fixedCandStr',
                );
                try {
                  await _peerConnection!.addCandidate(iceCandidate);
                } catch (e) {
                  debugPrint('[SenderWebRTC] Error adding direct remote candidate: $e');
                }
              } else {
                debugPrint(
                  '[SenderWebRTC] Queuing remote ICE candidate: $fixedCandStr',
                );
                _iceCandidateQueue.add(iceCandidate);
              }
            }
          }
          break;

        case 'ping':
          _sendSignalingMessage(SignalingMessage.pong());
          break;

        case 'prompter_command':
        case 'prompter_script_update':
          _prompterMessageController.add(message);
          break;

        case 'bye':
          debugPrint('[SenderWebRTC] Received Bye from receiver.');
          await stopMirroring();
          break;

        default:
          debugPrint('[SenderWebRTC] Unhandled message type: ${message.type}');
      }
    } catch (e, stack) {
      debugPrint('[SenderWebRTC] Error handling incoming message: $e\n$stack');
    }
  }

  void _startStatsPolling() {
    _stopStatsPolling();
    _lastBytesSent = 0;
    _lastFramesEncoded = 0;
    _lastStatsTime = DateTime.now();

    _statsTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_peerConnection == null) return;
      try {
        final reports = await _peerConnection!.getStats();
        double currentFps = 0.0;
        int rtt = 6;
        double bitrateMbps = 0.0;
        final now = DateTime.now();

        for (final report in reports) {
          final values = report.values;
          if (report.type == 'outbound-rtp' && values['kind'] == 'video') {
            final framesEncoded =
                int.tryParse(values['framesEncoded']?.toString() ?? '') ?? 0;
            if (_lastStatsTime != null && _lastFramesEncoded > 0) {
              final durationSec =
                  now.difference(_lastStatsTime!).inMilliseconds / 1000.0;
              if (durationSec > 0 && framesEncoded >= _lastFramesEncoded) {
                currentFps =
                    (framesEncoded - _lastFramesEncoded) / durationSec;
              }
            } else if (values['framesPerSecond'] != null) {
              currentFps =
                  double.tryParse(values['framesPerSecond'].toString()) ?? 0.0;
            }
            _lastFramesEncoded = framesEncoded;

            if (values['bytesSent'] != null) {
              final bytes = int.tryParse(values['bytesSent'].toString()) ?? 0;
              if (_lastStatsTime != null &&
                  bytes > _lastBytesSent &&
                  _lastBytesSent > 0) {
                final durationSec =
                    now.difference(_lastStatsTime!).inMilliseconds / 1000.0;
                if (durationSec > 0) {
                  bitrateMbps =
                      ((bytes - _lastBytesSent) * 8) / (durationSec * 1000000);
                }
              }
              _lastBytesSent = bytes;
            }
          } else if (report.type == 'candidate-pair' &&
              values['currentRoundTripTime'] != null) {
            final rttSec =
                double.tryParse(values['currentRoundTripTime'].toString()) ??
                    0.006;
            rtt = (rttSec * 1000).toInt();
          }
        }
        _lastStatsTime = now;

        // Read device thermal state and transmit telemetry to receiver
        final thermalInfo =
            await ForegroundServiceHelper.getDeviceThermalInfo();
        if (thermalInfo != null) {
          _sendSignalingMessage(
            SignalingMessage.thermalTelemetry(
              temperatureC: thermalInfo.temperatureC,
              thermalStatus: thermalInfo.thermalStatus,
              deviceName: thermalInfo.deviceName,
            ),
          );
        }

        _statsController.add(
          StreamPerformanceStats(
            fps: currentFps,
            latencyMs: rtt > 0 ? rtt : 6,
            bitrateMbps: bitrateMbps > 0
                ? double.parse(bitrateMbps.toStringAsFixed(2))
                : 3.5,
            senderTemperatureC: thermalInfo?.temperatureC,
            senderThermalStatus: thermalInfo?.thermalStatus,
            senderDeviceName: thermalInfo?.deviceName,
          ),
        );
      } catch (_) {}
    });
  }

  void _stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void> stopMirroring() async {
    debugPrint('[SenderWebRTC] Stopping screen mirroring session...');
    _stopStatsPolling();
    await _udpRelay.stop();

    _sendSignalingMessage(SignalingMessage.bye());

    await _channelSubscription?.cancel();
    _channelSubscription = null;

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
        await _peerConnection!.dispose();
      } catch (e) {
        debugPrint('[SenderWebRTC] Error closing peer connection: $e');
      }
      _peerConnection = null;
    }

    if (_localStream != null) {
      try {
        for (final track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
      } catch (e) {
        debugPrint('[SenderWebRTC] Error stopping local stream: $e');
      }
      _localStream = null;
    }

    _iceCandidateQueue.clear();
    _hasRemoteDescription = false;
    _lastBytesSent = 0;
    _lastFramesEncoded = 0;
    _lastStatsTime = null;

    if (Platform.isAndroid) {
      await ForegroundServiceHelper.setKeepScreenOn(false);
      await ForegroundServiceHelper.stopService();
    }

    _stateController.add(SenderConnectionState.disconnected);
    debugPrint('[SenderWebRTC] Mirroring session terminated cleanly.');
  }

  /// Seamlessly switches between back and front camera while streaming
  Future<void> switchCamera() async {
    if (_localStream == null ||
        _currentStreamSource != StreamSourceType.studioCamera) {
      return;
    }
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      try {
        await Helper.switchCamera(videoTracks.first);
        _currentCameraFacing =
            _currentCameraFacing == CameraFacingMode.environment
                ? CameraFacingMode.user
                : CameraFacingMode.environment;
        debugPrint(
          '[SenderWebRTC] Switched camera to ${_currentCameraFacing.label}',
        );
      } catch (e) {
        debugPrint('[SenderWebRTC] Error switching camera: $e');
      }
    }
  }

  /// Sends prompter state synchronization to connected receiver director
  void sendPrompterState(Map<String, dynamic> state) {
    _sendSignalingMessage(SignalingMessage.prompterStateSync(state));
  }

  Future<void> dispose() async {
    await stopMirroring();
    await _prompterMessageController.close();
    await _stateController.close();
    await _errorController.close();
    await _statsController.close();
  }
}
