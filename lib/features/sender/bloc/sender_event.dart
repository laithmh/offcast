import 'package:equatable/equatable.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/network/discovery_beacon.dart';
import '../data/sender_webrtc_service.dart';

abstract class SenderEvent extends Equatable {
  const SenderEvent();

  @override
  List<Object?> get props => [];
}

class SenderStartSharingRequested extends SenderEvent {
  final String targetHost;
  final int targetPort;
  final StreamingQualityPreset preset;
  final CodecEngine codecEngine;

  const SenderStartSharingRequested({
    required this.targetHost,
    this.targetPort = 8080,
    this.preset = StreamingQualityPreset.performance540p60,
    this.codecEngine = CodecEngine.vp8,
  });

  @override
  List<Object?> get props => [targetHost, targetPort, preset, codecEngine];
}

class SenderStopSharingRequested extends SenderEvent {
  const SenderStopSharingRequested();
}

class SenderConnectionStateUpdated extends SenderEvent {
  final SenderConnectionState connectionState;

  const SenderConnectionStateUpdated(this.connectionState);

  @override
  List<Object?> get props => [connectionState];
}

class SenderErrorOccurred extends SenderEvent {
  final String errorMessage;

  const SenderErrorOccurred(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

class SenderDiscoveredDeviceReceived extends SenderEvent {
  final DiscoveredDevice device;

  const SenderDiscoveredDeviceReceived(this.device);

  @override
  List<Object?> get props => [device];
}

class SenderGatewayDetected extends SenderEvent {
  final String gatewayIp;

  const SenderGatewayDetected(this.gatewayIp);

  @override
  List<Object?> get props => [gatewayIp];
}

class SenderScanSubnetRequested extends SenderEvent {
  const SenderScanSubnetRequested();
}

class SenderScanStatusUpdated extends SenderEvent {
  final bool isScanning;
  final String? foundIp;
  final bool isVerified;

  const SenderScanStatusUpdated({
    required this.isScanning,
    this.foundIp,
    this.isVerified = false,
  });

  @override
  List<Object?> get props => [isScanning, foundIp, isVerified];
}

class SenderClientIpDetected extends SenderEvent {
  final String clientIp;

  const SenderClientIpDetected(this.clientIp);

  @override
  List<Object?> get props => [clientIp];
}

class SenderQualityPresetChanged extends SenderEvent {
  final StreamingQualityPreset preset;

  const SenderQualityPresetChanged(this.preset);

  @override
  List<Object?> get props => [preset];
}

class SenderCodecEngineChanged extends SenderEvent {
  final CodecEngine codecEngine;

  const SenderCodecEngineChanged(this.codecEngine);

  @override
  List<Object?> get props => [codecEngine];
}
