export '../utils/sdp_candidate_sanitizer.dart';

enum StreamSourceType {
  screen(
    label: 'Screen Mirroring',
    description: 'Mirror phone display to monitor',
  ),
  studioCamera(
    label: 'Direct Studio Camera',
    description: 'Clean 1080p 60 FPS hardware camera feed with zero CPU load',
  );

  final String label;
  final String description;

  const StreamSourceType({required this.label, required this.description});
}

enum CameraFacingMode {
  environment(label: 'Rear Camera (Studio)'),
  user(label: 'Front Camera (Selfie)');

  final String label;
  const CameraFacingMode({required this.label});
}

enum CodecEngine {
  vp8(
    label: 'Universal Safe (VP8)',
    description: 'Clean & tear-free, 100% universal on all Android devices',
  ),
  h264(
    label: 'Hardware Turbo (H.264)',
    description:
        'Dedicated silicon acceleration for Snapdragon & Exynos devices',
  );

  final String label;
  final String description;

  const CodecEngine({required this.label, required this.description});
}

enum StreamingQualityPreset {
  performance540p60(
    label: 'Smooth Viewfinder (540p 60 FPS - Recommended)',
    description: 'Ultra-low latency & zero heat with buttery motion',
    targetFps: 60,
    maxWidth: 540,
    maxHeight: 1200,
    bitrateKbps: 1300,
  ),
  balanced720p60(
    label: 'Balanced Monitor (720p 45 FPS)',
    description: 'Crisp 720p clarity with balanced battery and thermal load',
    targetFps: 45,
    maxWidth: 720,
    maxHeight: 1600,
    bitrateKbps: 2200,
  ),
  ultra1080p30(
    label: 'Studio Detail (1080p 30 FPS)',
    description: 'Full HD 1080p detail for camera monitoring & static framing',
    targetFps: 30,
    maxWidth: 1080,
    maxHeight: 2400,
    bitrateKbps: 3200,
  );

  final String label;
  final String description;
  final int targetFps;
  final int maxWidth;
  final int maxHeight;
  final int bitrateKbps;

  const StreamingQualityPreset({
    required this.label,
    required this.description,
    required this.targetFps,
    required this.maxWidth,
    required this.maxHeight,
    required this.bitrateKbps,
  });
}

class StreamPerformanceStats {
  final double fps;
  final int latencyMs;
  final double bitrateMbps;
  final int width;
  final int height;
  final double? senderTemperatureC;
  final String? senderThermalStatus;
  final String? senderDeviceName;
  final double? receiverTemperatureC;
  final String? receiverThermalStatus;
  final String? receiverDeviceName;

  const StreamPerformanceStats({
    this.fps = 0.0,
    this.latencyMs = 0,
    this.bitrateMbps = 0.0,
    this.width = 0,
    this.height = 0,
    this.senderTemperatureC,
    this.senderThermalStatus,
    this.senderDeviceName,
    this.receiverTemperatureC,
    this.receiverThermalStatus,
    this.receiverDeviceName,
  });

  StreamPerformanceStats copyWith({
    double? fps,
    int? latencyMs,
    double? bitrateMbps,
    int? width,
    int? height,
    double? senderTemperatureC,
    String? senderThermalStatus,
    String? senderDeviceName,
    double? receiverTemperatureC,
    String? receiverThermalStatus,
    String? receiverDeviceName,
  }) {
    return StreamPerformanceStats(
      fps: fps ?? this.fps,
      latencyMs: latencyMs ?? this.latencyMs,
      bitrateMbps: bitrateMbps ?? this.bitrateMbps,
      width: width ?? this.width,
      height: height ?? this.height,
      senderTemperatureC: senderTemperatureC ?? this.senderTemperatureC,
      senderThermalStatus: senderThermalStatus ?? this.senderThermalStatus,
      senderDeviceName: senderDeviceName ?? this.senderDeviceName,
      receiverTemperatureC: receiverTemperatureC ?? this.receiverTemperatureC,
      receiverThermalStatus:
          receiverThermalStatus ?? this.receiverThermalStatus,
      receiverDeviceName: receiverDeviceName ?? this.receiverDeviceName,
    );
  }

  String get resolutionText =>
      width > 0 && height > 0 ? '${width}x$height' : '720p';
}

class WebRTCConstants {
  WebRTCConstants._();

  /// Signaling WebSocket Port
  static const int signalingPort = 8080;

  /// WebRTC Peer Configuration (Zero-latency direct local LAN P2P, no external STUN/TURN)
  static const Map<String, dynamic> rtcConfiguration = {
    'iceServers': <Map<String, dynamic>>[],
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': 'all',
    'candidateNetworkPolicy': 'all',
    'continualGatheringPolicy': 'gather_continually',
  };

  /// Screen capture constraints optimized for MediaTek & Qualcomm hardware encoders
  static Map<String, dynamic> getDisplayMediaConstraints({
    StreamingQualityPreset preset = StreamingQualityPreset.balanced720p60,
  }) {
    return {
      'audio': false,
      'video': {
        'mandatory': {
          'maxWidth': preset.maxWidth,
          'maxHeight': preset.maxHeight,
          'maxFrameRate': preset.targetFps,
        },
        'optional': <dynamic>[
          {'googCpuOveruseDetection': false},
          {'googCpuOveruseThreshold': 100},
          {'googHighpassFilter': false},
          {'googNoiseSuppression': false},
        ],
      },
    };
  }

  /// Default display media constraints
  static Map<String, dynamic> get displayMediaConstraints =>
      getDisplayMediaConstraints();

  /// Hardware camera capture constraints (1080p/720p 60/45/30 FPS)
  static Map<String, dynamic> getCameraMediaConstraints({
    StreamingQualityPreset preset = StreamingQualityPreset.balanced720p60,
    CameraFacingMode facing = CameraFacingMode.environment,
  }) {
    final isUltra = preset == StreamingQualityPreset.ultra1080p30;
    final isPerformance = preset == StreamingQualityPreset.performance540p60;
    final targetW = isUltra ? 1920 : (isPerformance ? 960 : 1280);
    final targetH = isUltra ? 1080 : (isPerformance ? 540 : 720);
    final isFront = facing == CameraFacingMode.user;

    return {
      'audio': false,
      'video': {
        'facingMode': isFront ? 'user' : 'environment',
        'mandatory': {
          'minWidth': isFront ? 640 : (isPerformance ? 960 : 1280),
          'minHeight': isFront ? 480 : (isPerformance ? 540 : 720),
          'maxWidth': targetW,
          'maxHeight': targetH,
          'maxFrameRate': preset.targetFps,
        },
        'optional': <dynamic>[
          {'minFrameRate': 15},
          {'googCpuOveruseDetection': false},
          {'googCpuOveruseThreshold': 100},
        ],
      },
    };
  }

  /// SDP Offer constraints for Sender (Unified Plan)
  static const Map<String, dynamic> senderOfferConstraints = {
    'mandatory': <String, dynamic>{
      'OfferToReceiveVideo': false,
      'OfferToReceiveAudio': false,
    },
    'optional': <dynamic>[],
  };

  /// SDP Answer constraints for Receiver (Unified Plan)
  static const Map<String, dynamic> receiverAnswerConstraints = {
    'mandatory': <String, dynamic>{
      'OfferToReceiveVideo': true,
      'OfferToReceiveAudio': false,
    },
    'optional': <dynamic>[],
  };
}

