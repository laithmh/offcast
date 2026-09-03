import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/discovery_beacon.dart';
import '../data/sender_webrtc_service.dart';
import 'sender_event.dart';
import 'sender_state.dart';

class SenderBloc extends Bloc<SenderEvent, SenderState> {
  final SenderWebRTCService webrtcService;
  final DiscoveryListener _discoveryListener = DiscoveryListener();

  StreamSubscription<SenderConnectionState>? _stateSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<DiscoveredDevice>? _discoverySubscription;
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

    _stateSubscription = webrtcService.stateStream.listen((connState) {
      add(SenderConnectionStateUpdated(connState));
    });

    _errorSubscription = webrtcService.errorStream.listen((err) {
      add(SenderErrorOccurred(err));
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
    emit(state.copyWith(clientIp: event.clientIp.isNotEmpty ? event.clientIp : null));
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

  Future<void> _onStartSharing(
    SenderStartSharingRequested event,
    Emitter<SenderState> emit,
  ) async {
    emit(
      state.copyWith(
        targetHost: event.targetHost,
        targetPort: event.targetPort,
        preset: event.preset,
        codecEngine: event.codecEngine,
        errorMessage: null,
      ),
    );

    await webrtcService.startMirroring(
      host: event.targetHost,
      port: event.targetPort,
      preset: event.preset,
      codecEngine: event.codecEngine,
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
    // Only update if not already actively streaming or connecting
    if (state.status == SenderConnectionState.disconnected ||
        state.status == SenderConnectionState.failed) {
      emit(
        state.copyWith(
          targetHost: event.device.ip,
          targetPort: event.device.port,
          discoveredDevice: event.device,
          isAutoDiscovered: true,
          isVerified: true,
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
    await _discoveryListener.dispose();
    await webrtcService.dispose();
    return super.close();
  }
}
