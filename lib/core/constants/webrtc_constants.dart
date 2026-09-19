export '../utils/sdp_candidate_sanitizer.dart';

enum StreamSourceType {
  screen(
    label: 'Screen Mirroring',
    description: 'Mirror phone display to monitor',
  );

  final String label;
  final String description;

  const StreamSourceType({required this.label, required this.description});
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
  cool540p30(
    label: 'Cool Viewfinder (540p 30 FPS)',
    description: 'Ultra-low heat & stable battery for long continuous shoots (Recommended)',
    targetFps: 30,
    maxWidth: 540,
    maxHeight: 1200,
    bitrateKbps: 850,
  ),
  hd720p30(
    label: 'HD Viewfinder (720p 30 FPS)',
    description: 'Crisp 720p clarity for framing and focus inspection',
    targetFps: 30,
    maxWidth: 720,
    maxHeight: 1600,
    bitrateKbps: 1800,
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
    StreamingQualityPreset preset = StreamingQualityPreset.cool540p30,
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
