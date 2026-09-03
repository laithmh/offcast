import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/discovery_beacon.dart';
import '../../../core/services/foreground_service_helper.dart';
import '../data/embedded_signaling_server.dart';
import '../data/receiver_webrtc_service.dart';
import 'receiver_event.dart';
import 'receiver_state.dart';

class ReceiverBloc extends Bloc<ReceiverEvent, ReceiverState> {
  final EmbeddedSignalingServer signalingServer;
  final ReceiverWebRTCService webrtcService;
  final DiscoveryBroadcaster _discoveryBroadcaster = DiscoveryBroadcaster();

  StreamSubscription<bool>? _clientStatusSub;
  StreamSubscription<bool>? _streamingStatusSub;
  Timer? _networkPollTimer;
  String _deviceName = 'Android Display';

  ReceiverBloc({required this.signalingServer, required this.webrtcService})
      : super(const ReceiverState()) {
    on<ReceiverStartServerRequested>(_onStartServer);
    on<ReceiverStopServerRequested>(_onStopServer);
    on<ReceiverClientStatusChanged>(_onClientStatusChanged);
    on<ReceiverStreamingStatusChanged>(_onStreamingStatusChanged);
    on<ReceiverIpSelected>(_onIpSelected);
    on<ReceiverNetworkPolled>(_onNetworkPolled);

    _clientStatusSub = signalingServer.clientConnectionStatus.listen((
      connected,
    ) {
      add(ReceiverClientStatusChanged(isClientConnected: connected));
    });

    _streamingStatusSub = webrtcService.isStreaming.listen((streaming) {
      add(ReceiverStreamingStatusChanged(isStreaming: streaming));
    });

    _startNetworkPolling();
  }

  void _startNetworkPolling() {
    _networkPollTimer?.cancel();
    _networkPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (isClosed || state.isStreaming) return;
      try {
        final allIps = await NetworkHelper.getAllLocalIps();
        final detectedIp = allIps.isNotEmpty ? allIps.first : null;
        if (!isClosed) {
          add(
            ReceiverNetworkPolled(
              detectedIp: detectedIp,
              availableIps: allIps,
            ),
          );
        }
      } catch (_) {}
    });
  }

  void _onNetworkPolled(
    ReceiverNetworkPolled event,
    Emitter<ReceiverState> emit,
  ) {
    if (state.isStreaming) return;

    final ipChanged = event.detectedIp != state.localIp;
    if (ipChanged) {
      debugPrint(
        '[ReceiverBloc] Network interface change detected: ${event.detectedIp}',
      );
      emit(
        state.copyWith(
          localIp: event.detectedIp,
          availableIps: event.availableIps,
        ),
      );

      // Re-broadcast UDP beacon on the newly detected IP
      if (event.detectedIp != null && state.status == ReceiverStatus.listening) {
        _discoveryBroadcaster.start(
          localIp: event.detectedIp!,
          signalingPort: state.port,
          deviceName: _deviceName,
        );
      }
    }
  }

  Future<void> _onStartServer(
    ReceiverStartServerRequested event,
    Emitter<ReceiverState> emit,
  ) async {
    emit(state.copyWith(status: ReceiverStatus.starting, errorMessage: null));

    try {
      await ForegroundServiceHelper.bindToWifiNetwork();
      await webrtcService.initialize();
      final port = await signalingServer.start(port: event.port);
      final allIps = await NetworkHelper.getAllLocalIps();
      final ip = allIps.isNotEmpty ? allIps.first : null;

      _deviceName = await ForegroundServiceHelper.getDeviceName();

      if (ip != null) {
        // Start zero-touch UDP discovery beacon
        await _discoveryBroadcaster.start(
          localIp: ip,
          signalingPort: port,
          deviceName: _deviceName,
        );
      }

      emit(
        state.copyWith(
          status: ReceiverStatus.listening,
          port: port,
          localIp: ip,
          availableIps: allIps,
          isClientConnected: false,
          isStreaming: false,
        ),
      );
    } catch (e) {
      debugPrint('[ReceiverBloc] Error starting server: $e');
      emit(
        state.copyWith(
          status: ReceiverStatus.error,
          errorMessage: 'Failed to start signaling server: $e',
        ),
      );
    }
  }

  void _onIpSelected(ReceiverIpSelected event, Emitter<ReceiverState> emit) {
    emit(state.copyWith(localIp: event.selectedIp));
    _discoveryBroadcaster.start(
      localIp: event.selectedIp,
      signalingPort: state.port,
      deviceName: _deviceName,
    );
  }

  Future<void> _onStopServer(
    ReceiverStopServerRequested event,
    Emitter<ReceiverState> emit,
  ) async {
    try {
      await _discoveryBroadcaster.stop();
      await signalingServer.stop();
      emit(
        state.copyWith(
          status: ReceiverStatus.stopped,
          isClientConnected: false,
          isStreaming: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReceiverStatus.error,
          errorMessage: 'Failed to stop server: $e',
        ),
      );
    }
  }

  void _onClientStatusChanged(
    ReceiverClientStatusChanged event,
    Emitter<ReceiverState> emit,
  ) {
    final newStatus = event.isClientConnected
        ? (state.isStreaming
            ? ReceiverStatus.streaming
            : ReceiverStatus.clientConnected)
        : ReceiverStatus.listening;

    if (event.isClientConnected) {
      _discoveryBroadcaster.stop();
    } else if (state.localIp != null && state.status == ReceiverStatus.listening) {
      _discoveryBroadcaster.start(
        localIp: state.localIp!,
        signalingPort: state.port,
        deviceName: _deviceName,
      );
    }

    emit(
      state.copyWith(
        isClientConnected: event.isClientConnected,
        status: newStatus,
      ),
    );
  }

  void _onStreamingStatusChanged(
    ReceiverStreamingStatusChanged event,
    Emitter<ReceiverState> emit,
  ) {
    final newStatus = event.isStreaming
        ? ReceiverStatus.streaming
        : (state.isClientConnected
            ? ReceiverStatus.clientConnected
            : ReceiverStatus.listening);

    emit(state.copyWith(isStreaming: event.isStreaming, status: newStatus));
  }

  @override
  Future<void> close() async {
    _networkPollTimer?.cancel();
    await _clientStatusSub?.cancel();
    await _streamingStatusSub?.cancel();
    await _discoveryBroadcaster.stop();
    await webrtcService.dispose();
    await signalingServer.dispose();
    return super.close();
  }
}
