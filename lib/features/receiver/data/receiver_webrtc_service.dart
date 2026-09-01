import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/models/signaling_message.dart';
import '../../../core/network/discovery_beacon.dart';
import '../../../core/network/local_udp_relay.dart';
import 'embedded_signaling_server.dart';

class ReceiverWebRTCService {
  final EmbeddedSignalingServer signalingServer;
  final RTCVideoRenderer renderer = RTCVideoRenderer();
  final LocalUdpRelay _udpRelay = LocalUdpRelay();

  RTCPeerConnection? _peerConnection;
  StreamSubscription<SignalingMessage>? _signalingSubscription;
  StreamSubscription<bool>? _clientStatusSubscription;

  final List<RTCIceCandidate> _iceCandidateQueue = [];
  bool _hasRemoteDescription = false;
  bool _isRendererInitialized = false;
  bool _isProcessingOffer = false;

  final StreamController<RTCPeerConnectionState> _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();
  final StreamController<bool> _streamingStatusController =
      StreamController<bool>.broadcast();
  final StreamController<StreamPerformanceStats> _statsController =
      StreamController<StreamPerformanceStats>.broadcast();

  Timer? _statsTimer;
  int _lastBytesReceived = 0;
  DateTime? _lastStatsTime;

  Stream<RTCPeerConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<bool> get isStreaming => _streamingStatusController.stream;
  Stream<StreamPerformanceStats> get statsStream => _statsController.stream;

  ReceiverWebRTCService({required this.signalingServer});

  Future<void> initialize() async {
    if (!_isRendererInitialized) {
      await renderer.initialize();
      _isRendererInitialized = true;
    }

    await _signalingSubscription?.cancel();
    _signalingSubscription = null;
    await _clientStatusSubscription?.cancel();
    _clientStatusSubscription = null;

    _signalingSubscription = signalingServer.incomingMessages.listen(
      _handleSignalingMessage,
    );
    _clientStatusSubscription = signalingServer.clientConnectionStatus.listen((
      connected,
    ) {
      if (!connected) {
        debugPrint(
          '[ReceiverWebRTC] Client disconnected, resetting WebRTC session.',
        );
        _resetPeerConnection();
      }
    });
  }

  String? _peerIp;

  String? _extractPeerIp(String? sdp) {
    if (sdp == null) return null;
    final match = RegExp(
      r'\b(10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(?:1[6-9]|2\d|3[01])\.\d+\.\d+|100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d+\.\d+)\b',
    ).firstMatch(sdp);
    return match?.group(1);
  }

  Future<void> _setupPeerConnection() async {
    _hasRemoteDescription = false;

    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
        await _peerConnection!.dispose();
      } catch (e) {
        debugPrint('[ReceiverWebRTC] Error closing peer connection: $e');
      }
      _peerConnection = null;
    }

    _peerConnection = await createPeerConnection(
      WebRTCConstants.rtcConfiguration,
    );

    // Pre-declare receive-only video transceiver for Unified Plan
    try {
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.RecvOnly,
        ),
      );
    } catch (_) {}

    _peerConnection!.onSignalingState = (RTCSignalingState state) {
      debugPrint('[ReceiverWebRTC] Signaling State: $state');
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[ReceiverWebRTC] ICE Connection State: $state');
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[ReceiverWebRTC] PeerConnection Connection State: $state');
      _connectionStateController.add(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _streamingStatusController.add(true);
        _startStatsPolling();
      } else if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _streamingStatusController.add(false);
        _stopStatsPolling();
      }
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        debugPrint('[ReceiverWebRTC] Raw onIceCandidate received: ${candidate.candidate}');
        final myIp = await NetworkHelper.findBestMatchingLocalIp(_peerIp) ??
            await NetworkHelper.getMyDeviceIp();

        var candStr = candidate.candidate!;
        final loopbackUdpMatch = RegExp(r'candidate:\S+ \d+ udp \d+ 127\.0\.0\.1 (\d+)').firstMatch(candStr);
        if (loopbackUdpMatch != null) {
          final loopbackPort = int.tryParse(loopbackUdpMatch.group(1)!);
          if (loopbackPort != null) {
            final relayPort = await _udpRelay.start(targetLoopbackPort: loopbackPort);
            candStr = candStr.replaceAll('127.0.0.1 $loopbackPort', '$myIp $relayPort');
          }
        }

        final fixedCandStr = SdpCandidateSanitizer.sanitizeCandidate(
          candStr,
          myIp,
        );
        if (fixedCandStr != null) {
          debugPrint('[ReceiverWebRTC] Local ICE Candidate generated: $fixedCandStr');
          final fixedCandidate = RTCIceCandidate(
            fixedCandStr,
            candidate.sdpMid ?? '0',
            candidate.sdpMLineIndex ?? 0,
          );
          signalingServer.sendMessage(SignalingMessage.candidate(fixedCandidate));
        }
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) async {
      debugPrint(
        '[ReceiverWebRTC] onTrack event: ${event.track.kind}, streams: ${event.streams.length}',
      );
      if (event.track.kind == 'video') {
        if (event.streams.isNotEmpty) {
          renderer.srcObject = event.streams[0];
        } else {
          try {
            final stream = await createLocalMediaStream('remote_stream');
            await stream.addTrack(event.track);
            renderer.srcObject = stream;
          } catch (e) {
            debugPrint('[ReceiverWebRTC] Error creating local stream for track: $e');
          }
        }
        _streamingStatusController.add(true);
      }
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      debugPrint('[ReceiverWebRTC] onAddStream event: ${stream.id}');
      renderer.srcObject = stream;
      _streamingStatusController.add(true);
    };

    _peerConnection!.onRemoveStream = (MediaStream stream) {
      debugPrint('[ReceiverWebRTC] onRemoveStream event');
      renderer.srcObject = null;
      _streamingStatusController.add(false);
    };
  }

  Future<void> _handleSignalingMessage(SignalingMessage message) async {
    try {
      switch (message.type) {
        case 'offer':
          if (message.sdp != null) {
            if (_isProcessingOffer) {
              debugPrint(
                '[ReceiverWebRTC] Ignoring duplicate concurrent SDP Offer.',
              );
              break;
            }
            _isProcessingOffer = true;
            try {
              _peerIp = _extractPeerIp(message.sdp);
              debugPrint(
                '[ReceiverWebRTC] Handling incoming SDP Offer from peer IP: $_peerIp...',
              );
              await _setupPeerConnection();

              final offerSdp = SdpCandidateSanitizer.sanitizeSdp(
                message.sdp,
                _peerIp,
              );
              debugPrint('[ReceiverWebRTC] <<< INCOMING SDP OFFER:\n$offerSdp');

              final description = RTCSessionDescription(offerSdp, 'offer');
              await _peerConnection!.setRemoteDescription(description);
              _hasRemoteDescription = true;

              // Drain queued ICE candidates received before the offer
              final queued = List<RTCIceCandidate>.from(_iceCandidateQueue);
              _iceCandidateQueue.clear();
              for (final candidate in queued) {
                debugPrint(
                  '[ReceiverWebRTC] Adding queued ICE candidate: ${candidate.candidate}',
                );
                try {
                  await _peerConnection!.addCandidate(candidate);
                } catch (e) {
                  debugPrint('[ReceiverWebRTC] Error adding candidate: $e');
                }
              }

              // Register gathering listener before setting local description
              final gatheringCompleter = Completer<void>();
              _peerConnection!.onIceGatheringState = (state) {
                debugPrint('[ReceiverWebRTC] ICE Gathering State: $state');
                if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
                  if (!gatheringCompleter.isCompleted) {
                    gatheringCompleter.complete();
                  }
                }
              };

              // Create and set SDP Answer
              final answer = await _peerConnection!.createAnswer(
                WebRTCConstants.receiverAnswerConstraints,
              );
              await _peerConnection!.setLocalDescription(answer);

              // Allow candidate gathering to embed host candidates in SDP
              await Future.any([
                gatheringCompleter.future,
                Future.delayed(const Duration(milliseconds: 1000)),
              ]);

              final fullAnswer = await _peerConnection!.getLocalDescription();
              final myIp =
                  await NetworkHelper.findBestMatchingLocalIp(_peerIp) ??
                      await NetworkHelper.getMyDeviceIp();
              var sdpStr = SdpCandidateSanitizer.sanitizeSdp(
                fullAnswer?.sdp ?? answer.sdp,
                myIp,
              );

              if (_udpRelay.publicPort != null) {
                // Point media section to relay port
                sdpStr = sdpStr.replaceAllMapped(
                  RegExp(r'm=video \d+ (UDP/TLS/RTP/SAVPF)'),
                  (m) => 'm=video ${_udpRelay.publicPort} ${m.group(1)}',
                );
              }

              debugPrint('[ReceiverWebRTC] >>> OUTGOING SDP ANSWER:\n$sdpStr');
              signalingServer.sendMessage(
                SignalingMessage.answer(sdpStr),
              );
            } finally {
              _isProcessingOffer = false;
            }
          }
          break;

        case 'candidate':
          if (message.candidate != null) {
            final candidateData = message.candidate!;
            final candStr = candidateData['candidate'] as String?;
            final fixedCandStr = SdpCandidateSanitizer.sanitizeCandidate(
              candStr,
              _peerIp,
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
                debugPrint('[ReceiverWebRTC] Adding direct ICE candidate: $fixedCandStr');
                try {
                  await _peerConnection!.addCandidate(iceCandidate);
                } catch (e) {
                  debugPrint('[ReceiverWebRTC] Error adding direct candidate: $e');
                }
              } else {
                debugPrint(
                  '[ReceiverWebRTC] Queuing ICE candidate (waiting for remote SDP): $fixedCandStr',
                );
                _iceCandidateQueue.add(iceCandidate);
              }
            }
          }
          break;

        case 'ping':
          signalingServer.sendMessage(SignalingMessage.pong());
          break;

        case 'pong':
          // Heartbeat ack
          break;

        case 'bye':
          debugPrint('[ReceiverWebRTC] Received Bye from sender.');
          await _resetPeerConnection();
          break;

        default:
          debugPrint('[ReceiverWebRTC] Unknown message type: ${message.type}');
      }
    } catch (e, stack) {
      debugPrint(
        '[ReceiverWebRTC] Error handling signaling message: $e\n$stack',
      );
    }
  }

  void _startStatsPolling() {
    _stopStatsPolling();
    _lastBytesReceived = 0;
    _lastStatsTime = DateTime.now();

    _statsTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_peerConnection == null) return;
      try {
        final reports = await _peerConnection!.getStats();
        double currentFps = 30.0;
        int rtt = 6;
        double bitrateMbps = 0.0;
        int width = renderer.videoWidth > 0 ? renderer.videoWidth : 1280;
        int height = renderer.videoHeight > 0 ? renderer.videoHeight : 720;

        for (final report in reports) {
          final values = report.values;
          if (report.type == 'inbound-rtp' && values['kind'] == 'video') {
            if (values['framesPerSecond'] != null) {
              currentFps =
                  double.tryParse(values['framesPerSecond'].toString()) ??
                      currentFps;
            }
            if (values['frameWidth'] != null) {
              width = int.tryParse(values['frameWidth'].toString()) ?? width;
            }
            if (values['frameHeight'] != null) {
              height = int.tryParse(values['frameHeight'].toString()) ?? height;
            }
            if (values['bytesReceived'] != null) {
              final bytes =
                  int.tryParse(values['bytesReceived'].toString()) ?? 0;
              final now = DateTime.now();
              if (_lastStatsTime != null &&
                  bytes > _lastBytesReceived &&
                  _lastBytesReceived > 0) {
                final durationSec =
                    now.difference(_lastStatsTime!).inMilliseconds / 1000.0;
                if (durationSec > 0) {
                  bitrateMbps =
                      ((bytes - _lastBytesReceived) * 8) / (durationSec * 1000000);
                }
              }
              _lastBytesReceived = bytes;
              _lastStatsTime = now;
            }
          } else if (report.type == 'candidate-pair' &&
              values['currentRoundTripTime'] != null) {
            final rttSec =
                double.tryParse(values['currentRoundTripTime'].toString()) ??
                    0.006;
            rtt = (rttSec * 1000).toInt();
          }
        }

        _statsController.add(
          StreamPerformanceStats(
            fps: currentFps,
            latencyMs: rtt > 0 ? rtt : 5,
            bitrateMbps: bitrateMbps > 0
                ? double.parse(bitrateMbps.toStringAsFixed(2))
                : 3.5,
            width: width,
            height: height,
          ),
        );
      } catch (_) {}
    });
  }

  void _stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void> _resetPeerConnection() async {
    _stopStatsPolling();
    await _udpRelay.stop();
    _isProcessingOffer = false;
    _hasRemoteDescription = false;
    _iceCandidateQueue.clear();
    _streamingStatusController.add(false);

    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
        await _peerConnection!.dispose();
      } catch (e) {
        debugPrint('[ReceiverWebRTC] Error closing peer connection: $e');
      }
      _peerConnection = null;
    }
    renderer.srcObject = null;
  }

  Future<void> dispose() async {
    _stopStatsPolling();
    await _udpRelay.stop();
    await _signalingSubscription?.cancel();
    await _clientStatusSubscription?.cancel();
    await _resetPeerConnection();
    if (_isRendererInitialized) {
      await renderer.dispose();
      _isRendererInitialized = false;
    }
    await _connectionStateController.close();
    await _streamingStatusController.close();
    await _statsController.close();
  }
}
