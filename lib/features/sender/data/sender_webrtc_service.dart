import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/models/signaling_message.dart';
import '../../../core/network/discovery_beacon.dart';
import '../../../core/network/local_udp_relay.dart';
import '../../../core/services/foreground_service_helper.dart';
import '../../../core/utils/webrtc_stats_calculator.dart';
import 'sender_signaling_client.dart';

enum SenderConnectionState {
  disconnected,
  capturingScreen,
  connectingSignaling,
  connectedSignaling,
  negotiatingWebRTC,
  streaming,
  failed,
}

/// Orchestrates Sender media capture (camera / screen), WebRTC PeerConnection,
/// in-place camera lens switching, and telemetry statistics.
class SenderWebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final SenderSignalingClient _signalingClient = SenderSignalingClient();
  final WebRtcStatsCalculator _statsCalculator = WebRtcStatsCalculator();
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
  StreamingQualityPreset _currentPreset =
      StreamingQualityPreset.cool540p30;
  CodecEngine _codecEngine = CodecEngine.h264;
  StreamSourceType _currentStreamSource = StreamSourceType.screen;
  Timer? _statsTimer;
  StreamSubscription<SignalingMessage>? _signalingSub;
  StreamSubscription<void>? _disconnectSub;
  StreamSubscription<String>? _signalingErrorSub;

  StreamSourceType get currentStreamSource => _currentStreamSource;

  /// Starts the ultra-low latency screen mirroring stream
  Future<void> startMirroring({
    required String host,
    int port = WebRTCConstants.signalingPort,
    StreamingQualityPreset preset = StreamingQualityPreset.cool540p30,
    CodecEngine codecEngine = CodecEngine.h264,
    StreamSourceType streamSource = StreamSourceType.screen,
    String? pairingPin,
  }) async {
    _currentTargetHost = host;
    _currentPreset = preset;
    _codecEngine = codecEngine;
    _currentStreamSource = streamSource;
    _iceCandidateQueue.clear();
    _hasRemoteDescription = false;

    try {
      // 1. Keep screen on
      await ForegroundServiceHelper.setKeepScreenOn(true);

      // 2. Acquire Display Media
      _stateController.add(SenderConnectionState.capturingScreen);
      if (Platform.isAndroid) {
        final granted = await Helper.requestCapturePermission();
        if (!granted) {
          throw Exception('User cancelled screen capture permission.');
        }
        await ForegroundServiceHelper.startService();
        // Give Android 14 MediaProjectionManager system service 200ms to register active FGS token
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      try {
        _localStream = await navigator.mediaDevices.getDisplayMedia(
          WebRTCConstants.getDisplayMediaConstraints(preset: preset),
        );
      } catch (e) {
        final errLower = e.toString().toLowerCase();
        if (Platform.isAndroid &&
            (errLower.contains('foreground service') ||
             errLower.contains('media projection') ||
             errLower.contains('securityexception'))) {
          debugPrint(
            '[SenderWebRTC] Transient Android MediaProjection timing glitch ($e). Retrying after 350ms...',
          );
          await Future<void>.delayed(const Duration(milliseconds: 350));
          try {
            _localStream = await navigator.mediaDevices.getDisplayMedia(
              WebRTCConstants.getDisplayMediaConstraints(preset: preset),
            );
          } catch (retryErr) {
            await ForegroundServiceHelper.stopService();
            rethrow;
          }
        } else {
          if (Platform.isAndroid) {
            await ForegroundServiceHelper.stopService();
          }
          rethrow;
        }
      }

      final videoTracks = _localStream?.getVideoTracks() ?? [];
      if (videoTracks.isEmpty) {
        throw Exception('No display video track obtained.');
      }

      // 3. Bind process to Wi-Fi network interface
      await ForegroundServiceHelper.bindToWifiNetwork();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // 4. Connect to Receiver Signaling Server via WebSocket with route retry
      _stateController.add(SenderConnectionState.connectingSignaling);
      _setupSignalingSubscriptions();

      int attempts = 0;
      while (true) {
        try {
          attempts++;
          await _signalingClient.connect(host, port, pin: pairingPin);
          break;
        } catch (connErr) {
          final errStr = connErr.toString();
          final isRetryable = errStr.contains('No route to host') ||
              errStr.contains('113') ||
              errStr.contains('Network is unreachable') ||
              errStr.contains('101') ||
              errStr.contains('Connection refused') ||
              errStr.contains('111');
          if (isRetryable && attempts < 4) {
            debugPrint(
              '[SenderWebRTC] Connection attempt $attempts failed ($connErr). Retrying in 600ms...',
            );
            await ForegroundServiceHelper.bindToWifiNetwork();
            await Future<void>.delayed(const Duration(milliseconds: 600));
            continue;
          }
          rethrow;
        }
      }
      _stateController.add(SenderConnectionState.connectedSignaling);

      // Transmit stream source metadata so receiver configures UI
      _signalingClient.send(
        SignalingMessage.streamMetadata(streamSource: streamSource),
      );

      // 5. Create WebRTC Peer Connection
      _stateController.add(SenderConnectionState.negotiatingWebRTC);
      _peerConnection = await createPeerConnection(
        WebRTCConstants.rtcConfiguration,
      );

      _peerConnection!.onSignalingState = (RTCSignalingState state) {
        debugPrint('[SenderWebRTC] Signaling State: $state');
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('[SenderWebRTC] ICE Connection State: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _errorController.add('WebRTC ICE connection failed. Peer unreachable.');
          _stateController.add(SenderConnectionState.failed);
          _stopStatsPolling();
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[SenderWebRTC] PeerConnection State: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _stateController.add(SenderConnectionState.streaming);
          _startStatsPolling();
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _stateController.add(SenderConnectionState.failed);
          _stopStatsPolling();
        }
      };

      bool hasPhysicalCandidate = false;

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          final myIp =
              await NetworkHelper.findBestMatchingLocalIp(_currentTargetHost) ??
              await NetworkHelper.getMyDeviceIp();

          var candStr = candidate.candidate!;
          final isPhysical =
              !candStr.contains('127.0.0.1') &&
              !candStr.contains('::1') &&
              !candStr.contains('localhost');

          if (isPhysical) {
            hasPhysicalCandidate = true;
            if (_udpRelay.publicPort != null) {
              await _udpRelay.stop();
            }
          }

          final loopbackUdpMatch = RegExp(
            r'candidate:\S+ \d+ udp \d+ 127\.0\.0\.1 (\d+)',
          ).firstMatch(candStr);
          if (loopbackUdpMatch != null && !hasPhysicalCandidate) {
            final loopbackPort = int.tryParse(loopbackUdpMatch.group(1)!);
            if (loopbackPort != null) {
              final relayPort = await _udpRelay.start(
                targetLoopbackPort: loopbackPort,
                remotePeerIp: _currentTargetHost,
              );
              candStr = candStr.replaceAll(
                '127.0.0.1 $loopbackPort',
                '$myIp $relayPort',
              );
            }
          }

          final fixedCandStr = SdpCandidateSanitizer.sanitizeCandidate(
            candStr,
            myIp,
          );
          if (fixedCandStr != null) {
            final fixedCandidate = RTCIceCandidate(
              fixedCandStr,
              candidate.sdpMid,
              candidate.sdpMLineIndex,
            );
            _signalingClient.send(
              SignalingMessage.candidate(fixedCandidate),
            );
          }
        }
      };

      // 6. Add local video track to peer connection
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // 7. Register ICE gathering listener
      final gatheringCompleter = Completer<void>();
      _peerConnection!.onIceGatheringState = (state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          if (!gatheringCompleter.isCompleted) gatheringCompleter.complete();
        }
      };

      // 8. Generate SDP Offer & Set Local Description
      final offer = await _peerConnection!.createOffer(
        WebRTCConstants.senderOfferConstraints,
      );
      await _peerConnection!.setLocalDescription(offer);

      // Configure video encoder parameters
      try {
        final senders = await _peerConnection!.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            final parameters = sender.parameters;
            parameters.degradationPreference =
                RTCDegradationPreference.MAINTAIN_FRAMERATE;
            if (parameters.encodings != null &&
                parameters.encodings!.isNotEmpty) {
              final scaleDown =
                  preset == StreamingQualityPreset.cool540p30 ? 2.0 : 1.5;
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

      // Wait for host ICE candidates to gather into SDP
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
      _signalingClient.send(SignalingMessage.offer(sdpStr));
    } catch (e, stack) {
      debugPrint('[SenderWebRTC] Error starting mirroring: $e\n$stack');
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || errorStr.contains('111')) {
        _errorController.add(
          'Target found at $host:$port, but Receiver Mode is not running. Please open Receiver Mode on the display device.',
        );
      } else if (errorStr.contains('Network is unreachable') ||
          errorStr.contains('101')) {
        _errorController.add(
          'Network is unreachable. Please connect this device to the Receiver’s Wi-Fi Hotspot.',
        );
      } else if (errorStr.contains('No route to host') ||
          errorStr.contains('113')) {
        _errorController.add(
          'Cannot reach Receiver at $host:$port. Ensure both devices are connected to the same Wi-Fi Hotspot and Receiver Mode is active.',
        );
      } else if (e is TimeoutException) {
        _errorController.add(
          'Connection to $host:$port timed out. Ensure Receiver Mode is running and IP matches the display screen.',
        );
      } else {
        _errorController.add('Failed to start mirroring: $e');
      }
      _stateController.add(SenderConnectionState.failed);
      await stopMirroring(preserveFailedState: true);
    }
  }

  void _setupSignalingSubscriptions() {
    _signalingSub?.cancel();
    _signalingSub = _signalingClient.onMessage.listen(_handleSignalingMessage);

    _disconnectSub?.cancel();
    _disconnectSub = _signalingClient.onDisconnected.listen((_) {
      if (_peerConnection != null) {
        _stateController.add(SenderConnectionState.disconnected);
      }
    });

    _signalingErrorSub?.cancel();
    _signalingErrorSub = _signalingClient.onError.listen((err) {
      _errorController.add(err);
      _stateController.add(SenderConnectionState.failed);
    });
  }

  Future<void> _handleSignalingMessage(SignalingMessage message) async {
    try {
      switch (message.type) {
        case 'answer':
          if (message.sdp != null) {
            final answerSdp = SdpCandidateSanitizer.sanitizeSdp(
              message.sdp,
              _currentTargetHost,
              codecEngine: _codecEngine,
            );
            final description = RTCSessionDescription(answerSdp, 'answer');
            await _peerConnection!.setRemoteDescription(description);
            _hasRemoteDescription = true;

            // Apply active encoder bitrate/framerate post-answer
            try {
              final senders = await _peerConnection!.getSenders();
              for (final sender in senders) {
                if (sender.track?.kind == 'video') {
                  final parameters = sender.parameters;
                  parameters.degradationPreference =
                      RTCDegradationPreference.MAINTAIN_FRAMERATE;
                  if (parameters.encodings != null &&
                      parameters.encodings!.isNotEmpty) {
                    final scaleDown =
                        _currentPreset == StreamingQualityPreset.cool540p30
                            ? 2.0
                            : 1.5;
                    for (final encoding in parameters.encodings!) {
                      encoding.maxBitrate = _currentPreset.bitrateKbps * 1000;
                      encoding.minBitrate =
                          (_currentPreset.bitrateKbps * 0.70).toInt() * 1000;
                      encoding.maxFramerate = _currentPreset.targetFps;
                      encoding.scaleResolutionDownBy = scaleDown;
                    }
                  }
                  await sender.setParameters(parameters);
                }
              }
            } catch (_) {}

            // Drain queued ICE candidates
            final queued = List<RTCIceCandidate>.from(_iceCandidateQueue);
            _iceCandidateQueue.clear();
            for (final candidate in queued) {
              try {
                await _peerConnection!.addCandidate(candidate);
              } catch (_) {}
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
              final candidate = RTCIceCandidate(
                fixedCandStr,
                candidateData['sdpMid'] as String?,
                candidateData['sdpMLineIndex'] as int?,
              );
              if (_hasRemoteDescription && _peerConnection != null) {
                await _peerConnection!.addCandidate(candidate);
              } else {
                _iceCandidateQueue.add(candidate);
              }
            }
          }
          break;

        case 'ping':
          _signalingClient.send(SignalingMessage.pong());
          break;

        case 'prompter_command':
        case 'prompter_script_update':
          _prompterMessageController.add(message);
          break;

        case 'bye':
          await stopMirroring();
          break;
      }
    } catch (e, stack) {
      debugPrint('[SenderWebRTC] Error handling message: $e\n$stack');
    }
  }

  void _startStatsPolling() {
    _stopStatsPolling();
    _statsCalculator.reset();

    _statsTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_peerConnection == null) return;
      try {
        final reports = await _peerConnection!.getStats();
        final metrics = _statsCalculator.calculateOutbound(
          reports,
          fallbackWidth: _currentPreset.maxWidth,
          fallbackHeight: _currentPreset.maxHeight,
        );

        final thermalInfo =
            await ForegroundServiceHelper.getDeviceThermalInfo();
        if (thermalInfo != null) {
          _signalingClient.send(
            SignalingMessage.thermalTelemetry(
              temperatureC: thermalInfo.temperatureC,
              thermalStatus: thermalInfo.thermalStatus,
              deviceName: thermalInfo.deviceName,
            ),
          );
        }

        _statsController.add(
          StreamPerformanceStats(
            fps: metrics.fps,
            latencyMs: metrics.latencyMs > 0 ? metrics.latencyMs : 6,
            bitrateMbps: metrics.bitrateMbps > 0
                ? double.parse(metrics.bitrateMbps.toStringAsFixed(2))
                : 3.5,
            width: metrics.width,
            height: metrics.height,
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

  Future<void> stopMirroring({bool preserveFailedState = false}) async {
    _stopStatsPolling();
    await _udpRelay.stop();

    _signalingClient.send(SignalingMessage.bye());
    await _signalingClient.disconnect();

    _signalingSub?.cancel();
    _disconnectSub?.cancel();
    _signalingErrorSub?.cancel();

    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
        await _peerConnection!.dispose();
      } catch (_) {}
      _peerConnection = null;
    }

    if (_localStream != null) {
      try {
        for (final track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
      } catch (_) {}
      _localStream = null;
    }

    _iceCandidateQueue.clear();
    _hasRemoteDescription = false;

    if (Platform.isAndroid) {
      await ForegroundServiceHelper.setKeepScreenOn(false);
      await ForegroundServiceHelper.stopService();
    }

    if (!preserveFailedState && !_stateController.isClosed) {
      _stateController.add(SenderConnectionState.disconnected);
    }
  }



  void sendPrompterState(Map<String, dynamic> state) {
    _signalingClient.send(SignalingMessage.prompterStateSync(state));
  }

  Future<void> dispose() async {
    await stopMirroring();
    _signalingClient.dispose();
    await _prompterMessageController.close();
    await _stateController.close();
    await _errorController.close();
    await _statsController.close();
  }
}
