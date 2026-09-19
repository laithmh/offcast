import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/signaling_message.dart';
import '../../../core/network/discovery_beacon.dart';
import '../../../core/services/foreground_service_helper.dart';
import '../data/sender_webrtc_service.dart';
import 'sender_event.dart';
import 'sender_state.dart';

class SenderBloc extends Bloc<SenderEvent, SenderState> {
  final SenderWebRTCService webrtcService;
  final DiscoveryListener _discoveryListener = DiscoveryListener();

  StreamSubscription<SenderConnectionState>? _stateSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<DiscoveredDevice>? _discoverySubscription;
  StreamSubscription<SignalingMessage>? _prompterSubscription;
  Timer? _networkPollTimer;

  SenderBloc({required this.webrtcService}) : super(const SenderState()) {
    on<SenderStartSharingRequested>(_onStartSharing);
    on<SenderStopSharingRequested>(_onStopSharing);
    on<SenderConnectionStateUpdated>(_onConnectionStateUpdated);
    on<SenderErrorOccurred>(_onErrorOccurred);
    on<SenderDiscoveredDeviceReceived>(_onDiscoveredDeviceReceived);
    on<SenderGatewayDetected>(_onGatewayDetected);
    on<SenderScanSubnetRequested>(_onScanSubnetRequested);
    on<SenderScanStatusUpdated>(_onScanStatusUpdated);
    on<SenderClientIpDetected>(_onClientIpDetected);
    on<SenderQualityPresetChanged>(_onQualityPresetChanged);
    on<SenderCodecEngineChanged>(_onCodecEngineChanged);
    on<SenderStreamSourceChanged>(_onStreamSourceChanged);
    on<SenderPrompterScriptUpdated>(_onPrompterScriptUpdated);
    on<SenderPrompterSpeedChanged>(_onPrompterSpeedChanged);
    on<SenderPrompterFontSizeChanged>(_onPrompterFontSizeChanged);
    on<SenderPrompterMirrorToggled>(_onPrompterMirrorToggled);
    on<SenderPrompterVoiceActivationToggled>(_onPrompterVoiceActivationToggled);
    on<SenderPrompterPlayPauseToggled>(_onPrompterPlayPauseToggled);
    on<SenderPrompterRewindRequested>(_onPrompterRewindRequested);
    on<SenderPrompterOverlayToggled>(_onPrompterOverlayToggled);
    on<SenderPrompterRemoteMessageReceived>(_onPrompterRemoteMessageReceived);
    on<SenderPrompterProgressUpdated>(_onPrompterProgressUpdated);
    on<SenderPinChanged>(_onPinChanged);

    _stateSubscription = webrtcService.stateStream.listen((connState) {
      add(SenderConnectionStateUpdated(connState));
    });

    _errorSubscription = webrtcService.errorStream.listen((err) {
      add(SenderErrorOccurred(err));
    });

    _prompterSubscription = webrtcService.prompterMessageStream.listen((msg) {
      add(SenderPrompterRemoteMessageReceived(msg));
    });

    // Start auto-discovery listener
    _discoveryListener.start();
    _discoverySubscription = _discoveryListener.discoveredDevices.listen((
      device,
    ) {
      add(SenderDiscoveredDeviceReceived(device));
    });

    // Auto-detect client IP, Gateway, and initiate active port 8080 subnet probe
    _initiateAutoDetection();
    _startNetworkPolling();
  }

  void _startNetworkPolling() {
    _networkPollTimer?.cancel();
    _networkPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (isClosed || state.isStreaming) return;
      try {
        final clientIp = await NetworkHelper.getMyDeviceIp();
        if (clientIp != state.clientIp && !isClosed) {
          add(SenderClientIpDetected(clientIp ?? ''));
          if (clientIp != null && !state.isVerified) {
            final gateway = await NetworkHelper.detectHotspotGatewayIp();
            if (gateway != null && !isClosed) {
              add(SenderGatewayDetected(gateway));
            }
            _performSubnetScan();
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _initiateAutoDetection() async {
    await ForegroundServiceHelper.bindToWifiNetwork();
    final clientIp = await NetworkHelper.getMyDeviceIp();
    if (clientIp != null && !isClosed) {
      add(SenderClientIpDetected(clientIp));
    }

    final gateway = await NetworkHelper.detectHotspotGatewayIp();
    if (gateway != null && !isClosed) {
      add(SenderGatewayDetected(gateway));
    }

    // Active port 8080 probe across subnet
    await _performSubnetScan();
  }

  Future<void> _performSubnetScan() async {
    if (isClosed) return;
    add(const SenderScanStatusUpdated(isScanning: true));

    final activeIp = await NetworkHelper.scanSubnetForSignalingServer(
      port: state.targetPort,
      onFound: (ip) {
        if (!isClosed) {
          add(
            SenderScanStatusUpdated(
              isScanning: false,
              foundIp: ip,
              isVerified: true,
            ),
          );
        }
      },
    );

    if (!isClosed) {
      add(
        SenderScanStatusUpdated(
          isScanning: false,
          foundIp: activeIp,
          isVerified: activeIp != null,
        ),
      );
    }
  }

  void _onScanSubnetRequested(
    SenderScanSubnetRequested event,
    Emitter<SenderState> emit,
  ) {
    _performSubnetScan();
  }

  void _onScanStatusUpdated(
    SenderScanStatusUpdated event,
    Emitter<SenderState> emit,
  ) {
    if (event.foundIp != null) {
      emit(
        state.copyWith(
          isScanning: event.isScanning,
          targetHost: event.foundIp,
          isAutoDiscovered: true,
          isVerified: event.isVerified,
        ),
      );
    } else {
      emit(
        state.copyWith(
          isScanning: event.isScanning,
          isVerified: event.isVerified,
        ),
      );
    }
  }

  void _onClientIpDetected(
    SenderClientIpDetected event,
    Emitter<SenderState> emit,
  ) {
    emit(
      state.copyWith(
        clientIp: event.clientIp.isNotEmpty ? event.clientIp : null,
      ),
    );
  }

  void _onGatewayDetected(
    SenderGatewayDetected event,
    Emitter<SenderState> emit,
  ) {
    if (state.discoveredDevice == null &&
        !state.isVerified &&
        (state.status == SenderConnectionState.disconnected ||
            state.status == SenderConnectionState.failed)) {
      emit(state.copyWith(targetHost: event.gatewayIp, isAutoDiscovered: true));
    }
  }

  void _onQualityPresetChanged(
    SenderQualityPresetChanged event,
    Emitter<SenderState> emit,
  ) {
    emit(state.copyWith(preset: event.preset));
  }

  void _onCodecEngineChanged(
    SenderCodecEngineChanged event,
    Emitter<SenderState> emit,
  ) {
    emit(state.copyWith(codecEngine: event.codecEngine));
  }

  void _onStreamSourceChanged(
    SenderStreamSourceChanged event,
    Emitter<SenderState> emit,
  ) {
    emit(state.copyWith(streamSource: event.streamSource));
  }

  void _onPrompterScriptUpdated(
    SenderPrompterScriptUpdated event,
    Emitter<SenderState> emit,
  ) {
    final updated = state.prompterConfig.copyWith(scriptText: event.scriptText);
    emit(state.copyWith(prompterConfig: updated));
    if (state.isStreaming) {
      webrtcService.sendPrompterState(updated.toJson());
    }
  }

  void _onPrompterSpeedChanged(
    SenderPrompterSpeedChanged event,
    Emitter<SenderState> emit,
  ) {
    final updated = state.prompterConfig.copyWith(
      scrollSpeedWpm: event.speedWpm,
    );
    emit(state.copyWith(prompterConfig: updated));
    if (state.isStreaming) {
      webrtcService.sendPrompterState(updated.toJson());
    }
  }

  void _onPrompterFontSizeChanged(
    SenderPrompterFontSizeChanged event,
    Emitter<SenderState> emit,
  ) {
    final updated = state.prompterConfig.copyWith(fontSize: event.fontSize);
    emit(state.copyWith(prompterConfig: updated));
    if (state.isStreaming) {
      webrtcService.sendPrompterState(updated.toJson());
    }
  }

  void _onPrompterMirrorToggled(
    SenderPrompterMirrorToggled event,
    Emitter<SenderState> emit,
  ) {
    final updated = state.prompterConfig.copyWith(
      isMirrored: !state.prompterConfig.isMirrored,
    );
    emit(state.copyWith(prompterConfig: updated));
    if (state.isStreaming) {
      webrtcService.sendPrompterState(updated.toJson());
    }
  }

  void _onPrompterVoiceActivationToggled(
    SenderPrompterVoiceActivationToggled event,
    Emitter<SenderState> emit,
  ) {
    final updated = state.prompterConfig.copyWith(
      isVoiceActivated: !state.prompterConfig.isVoiceActivated,
    );
    emit(state.copyWith(prompterConfig: updated));
    if (state.isStreaming) {
      webrtcService.sendPrompterState(updated.toJson());
    }
  }

  void _onPrompterPlayPauseToggled(
    SenderPrompterPlayPauseToggled event,
    Emitter<SenderState> emit,
  ) {
    final updated = state.prompterConfig.copyWith(
      isPlaying: !state.prompterConfig.isPlaying,
    );
    emit(state.copyWith(prompterConfig: updated));
    if (state.isStreaming) {
      webrtcService.sendPrompterState(updated.toJson());
    }
  }

  void _onPrompterRewindRequested(
    SenderPrompterRewindRequested event,
    Emitter<SenderState> emit,
  ) {
    final updated = state.prompterConfig.copyWith(scrollProgress: 0.0);
    emit(state.copyWith(prompterConfig: updated));
    if (state.isStreaming) {
      webrtcService.sendPrompterState(updated.toJson());
    }
  }

  void _onPrompterOverlayToggled(
    SenderPrompterOverlayToggled event,
    Emitter<SenderState> emit,
  ) {
    emit(state.copyWith(isPrompterOverlay: !state.isPrompterOverlay));
  }

  void _onPrompterProgressUpdated(
    SenderPrompterProgressUpdated event,
    Emitter<SenderState> emit,
  ) {
    emit(
      state.copyWith(
        prompterConfig: state.prompterConfig.copyWith(
          scrollProgress: event.progress,
        ),
      ),
    );
  }

  Future<void> _onPrompterRemoteMessageReceived(
    SenderPrompterRemoteMessageReceived event,
    Emitter<SenderState> emit,
  ) async {
    final msg = event.message;
    if (msg.type == 'prompter_script_update') {
      final text = msg.payload?['text'] as String?;
      if (text != null && text.isNotEmpty) {
        final updated = state.prompterConfig.copyWith(scriptText: text);
        emit(state.copyWith(prompterConfig: updated));
      }
    } else if (msg.type == 'prompter_command') {
      final action = msg.payload?['action'] as String?;
      switch (action) {
        case 'play':
          emit(
            state.copyWith(
              prompterConfig: state.prompterConfig.copyWith(isPlaying: true),
            ),
          );
          break;
        case 'pause':
          emit(
            state.copyWith(
              prompterConfig: state.prompterConfig.copyWith(isPlaying: false),
            ),
          );
          break;
        case 'rewind':
          emit(
            state.copyWith(
              prompterConfig: state.prompterConfig.copyWith(
                scrollProgress: 0.0,
              ),
            ),
          );
          break;
        case 'set_speed':
          final spd = (msg.payload?['speedWpm'] as num?)?.toDouble();
          if (spd != null) {
            emit(
              state.copyWith(
                prompterConfig: state.prompterConfig.copyWith(
                  scrollSpeedWpm: spd,
                ),
              ),
            );
          }
          break;
        case 'set_font_size':
          final fs = (msg.payload?['fontSize'] as num?)?.toDouble();
          if (fs != null) {
            emit(
              state.copyWith(
                prompterConfig: state.prompterConfig.copyWith(fontSize: fs),
              ),
            );
          }
          break;
        case 'set_voice_activated':
          final va = msg.payload?['isVoiceActivated'] as bool?;
          if (va != null) {
            emit(
              state.copyWith(
                prompterConfig: state.prompterConfig.copyWith(
                  isVoiceActivated: va,
                ),
              ),
            );
          }
          break;
      }
    }
  }

  void _onPinChanged(SenderPinChanged event, Emitter<SenderState> emit) {
    emit(state.copyWith(pairingPin: event.pin));
  }

  Future<void> _onStartSharing(
    SenderStartSharingRequested event,
    Emitter<SenderState> emit,
  ) async {
    final effectivePin = event.pairingPin ?? state.pairingPin;
    emit(
      state.copyWith(
        targetHost: event.targetHost,
        targetPort: event.targetPort,
        preset: event.preset,
        codecEngine: event.codecEngine,
        streamSource: event.streamSource,
        pairingPin: effectivePin,
        errorMessage: null,
      ),
    );

    await webrtcService.startMirroring(
      host: event.targetHost,
      port: event.targetPort,
      preset: event.preset,
      codecEngine: event.codecEngine,
      streamSource: event.streamSource,
      pairingPin: effectivePin.isNotEmpty ? effectivePin : null,
    );
  }

  Future<void> _onStopSharing(
    SenderStopSharingRequested event,
    Emitter<SenderState> emit,
  ) async {
    await webrtcService.stopMirroring();
    emit(
      state.copyWith(
        status: SenderConnectionState.disconnected,
        errorMessage: null,
      ),
    );
  }

  void _onConnectionStateUpdated(
    SenderConnectionStateUpdated event,
    Emitter<SenderState> emit,
  ) {
    emit(state.copyWith(status: event.connectionState));
    if (event.connectionState == SenderConnectionState.streaming) {
      webrtcService.sendPrompterState(state.prompterConfig.toJson());
    }
  }

  void _onErrorOccurred(SenderErrorOccurred event, Emitter<SenderState> emit) {
    emit(
      state.copyWith(
        status: SenderConnectionState.failed,
        errorMessage: event.errorMessage,
      ),
    );
  }

  void _onDiscoveredDeviceReceived(
    SenderDiscoveredDeviceReceived event,
    Emitter<SenderState> emit,
  ) {
    if (state.status == SenderConnectionState.disconnected ||
        state.status == SenderConnectionState.failed) {
      emit(
        state.copyWith(
          targetHost: event.device.ip,
          targetPort: event.device.port,
          discoveredDevice: event.device,
          isAutoDiscovered: true,
          isVerified: true,
          pairingPin: (event.device.pin != null && event.device.pin!.isNotEmpty)
              ? event.device.pin
              : state.pairingPin,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _networkPollTimer?.cancel();
    await _stateSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _discoverySubscription?.cancel();
    await _prompterSubscription?.cancel();
    await _discoveryListener.dispose();
    await webrtcService.dispose();
    return super.close();
  }
}
