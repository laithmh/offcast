import 'package:equatable/equatable.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/models/prompter_model.dart';
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
  final CodecEngine codecEngine;
  final StreamSourceType streamSource;
  final CameraFacingMode cameraFacing;
  final PrompterConfig prompterConfig;
  final bool isPrompterOverlay;
  final String pairingPin;
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
    this.preset = StreamingQualityPreset.performance540p60,
    this.codecEngine = CodecEngine.vp8,
    this.streamSource = StreamSourceType.studioCamera,
    this.cameraFacing = CameraFacingMode.environment,
    this.prompterConfig = const PrompterConfig(),
    this.isPrompterOverlay = false,
    this.pairingPin = '',
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
    CodecEngine? codecEngine,
    StreamSourceType? streamSource,
    CameraFacingMode? cameraFacing,
    PrompterConfig? prompterConfig,
    bool? isPrompterOverlay,
    String? pairingPin,
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
      codecEngine: codecEngine ?? this.codecEngine,
      streamSource: streamSource ?? this.streamSource,
      cameraFacing: cameraFacing ?? this.cameraFacing,
      prompterConfig: prompterConfig ?? this.prompterConfig,
      isPrompterOverlay: isPrompterOverlay ?? this.isPrompterOverlay,
      pairingPin: pairingPin ?? this.pairingPin,
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
    codecEngine,
    streamSource,
    cameraFacing,
    prompterConfig,
    isPrompterOverlay,
    pairingPin,
    errorMessage,
  ];
}
