import 'package:equatable/equatable.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/models/signaling_message.dart';
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
  final StreamSourceType streamSource;
  final CameraFacingMode cameraFacing;

  const SenderStartSharingRequested({
    required this.targetHost,
    this.targetPort = 8080,
    this.preset = StreamingQualityPreset.performance540p60,
    this.codecEngine = CodecEngine.vp8,
    this.streamSource = StreamSourceType.screen,
    this.cameraFacing = CameraFacingMode.environment,
  });

  @override
  List<Object?> get props => [
    targetHost,
    targetPort,
    preset,
    codecEngine,
    streamSource,
    cameraFacing,
  ];
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

class SenderStreamSourceChanged extends SenderEvent {
  final StreamSourceType streamSource;

  const SenderStreamSourceChanged(this.streamSource);

  @override
  List<Object?> get props => [streamSource];
}

class SenderCameraFacingToggled extends SenderEvent {
  const SenderCameraFacingToggled();
}

class SenderPrompterScriptUpdated extends SenderEvent {
  final String scriptText;

  const SenderPrompterScriptUpdated(this.scriptText);

  @override
  List<Object?> get props => [scriptText];
}

class SenderPrompterSpeedChanged extends SenderEvent {
  final double speedWpm;

  const SenderPrompterSpeedChanged(this.speedWpm);

  @override
  List<Object?> get props => [speedWpm];
}

class SenderPrompterFontSizeChanged extends SenderEvent {
  final double fontSize;

  const SenderPrompterFontSizeChanged(this.fontSize);

  @override
  List<Object?> get props => [fontSize];
}

class SenderPrompterMirrorToggled extends SenderEvent {
  const SenderPrompterMirrorToggled();
}

class SenderPrompterVoiceActivationToggled extends SenderEvent {
  const SenderPrompterVoiceActivationToggled();
}

class SenderPrompterPlayPauseToggled extends SenderEvent {
  const SenderPrompterPlayPauseToggled();
}

class SenderPrompterRewindRequested extends SenderEvent {
  const SenderPrompterRewindRequested();
}

class SenderPrompterOverlayToggled extends SenderEvent {
  const SenderPrompterOverlayToggled();
}

class SenderPrompterRemoteMessageReceived extends SenderEvent {
  final SignalingMessage message;

  const SenderPrompterRemoteMessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}

class SenderPrompterProgressUpdated extends SenderEvent {
  final double progress;

  const SenderPrompterProgressUpdated(this.progress);

  @override
  List<Object?> get props => [progress];
}
