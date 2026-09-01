import 'package:equatable/equatable.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/network/discovery_beacon.dart';
import '../data/sender_webrtc_service.dart';

class SenderState extends Equatable {
  final SenderConnectionState status;
  final String targetHost;
  final int targetPort;
  final DiscoveredDevice? discoveredDevice;
  final bool isAutoDiscovered;
  final bool isScanning;
  final bool isVerified;
  final String? clientIp;
  final StreamingQualityPreset preset;
  final String? errorMessage;

  const SenderState({
    this.status = SenderConnectionState.disconnected,
    this.targetHost = '',
    this.targetPort = 8080,
    this.discoveredDevice,
    this.isAutoDiscovered = false,
    this.isScanning = false,
    this.isVerified = false,
    this.clientIp,
    this.preset = StreamingQualityPreset.balanced720p30,
    this.errorMessage,
  });

  bool get isStreaming => status == SenderConnectionState.streaming;
  bool get isBusy =>
      status == SenderConnectionState.connectingSignaling ||
      status == SenderConnectionState.connectedSignaling ||
      status == SenderConnectionState.capturingScreen ||
      status == SenderConnectionState.negotiatingWebRTC;

  SenderState copyWith({
    SenderConnectionState? status,
    String? targetHost,
    int? targetPort,
    DiscoveredDevice? discoveredDevice,
    bool? isAutoDiscovered,
    bool? isScanning,
    bool? isVerified,
    String? clientIp,
    StreamingQualityPreset? preset,
    String? errorMessage,
  }) {
    return SenderState(
      status: status ?? this.status,
      targetHost: targetHost ?? this.targetHost,
      targetPort: targetPort ?? this.targetPort,
      discoveredDevice: discoveredDevice ?? this.discoveredDevice,
      isAutoDiscovered: isAutoDiscovered ?? this.isAutoDiscovered,
      isScanning: isScanning ?? this.isScanning,
      isVerified: isVerified ?? this.isVerified,
      clientIp: clientIp ?? this.clientIp,
      preset: preset ?? this.preset,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    targetHost,
    targetPort,
    discoveredDevice,
    isAutoDiscovered,
    isScanning,
    isVerified,
    clientIp,
    preset,
    errorMessage,
  ];
}
