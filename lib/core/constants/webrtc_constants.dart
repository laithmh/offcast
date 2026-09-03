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

  const StreamSourceType({
    required this.label,
    required this.description,
  });
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
    description: 'Dedicated silicon acceleration for Snapdragon & Exynos devices',
  );

  final String label;
  final String description;

  const CodecEngine({
    required this.label,
    required this.description,
  });
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

  String get resolutionText => width > 0 && height > 0 ? '${width}x$height' : '720p';
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
    return {
      'audio': false,
      'video': {
        'facingMode': facing == CameraFacingMode.environment ? 'environment' : 'user',
        'mandatory': {
          'minWidth': preset == StreamingQualityPreset.performance540p60 ? 960 : 1280,
          'minHeight': preset == StreamingQualityPreset.performance540p60 ? 540 : 720,
          'maxWidth': preset.maxWidth,
          'maxHeight': preset.maxHeight,
          'minFrameRate': 30,
          'maxFrameRate': preset.targetFps,
        },
        'optional': <dynamic>[
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

class SdpCandidateSanitizer {
  static final RegExp _ipv4Pattern = RegExp(
    r'\b(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\b',
  );

  /// Checks if an IPv4 address is private LAN (10.x, 172.16-31.x, 192.168.x, 100.64-127.x, 169.254.x)
  static bool isPrivateIPv4(String ip) {
    if (ip == '127.0.0.1' || ip == '0.0.0.0' || ip.isEmpty) return false;
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return false;

    final p0 = parts[0]!;
    final p1 = parts[1]!;

    if (p0 == 127 || p0 >= 224 || p0 == 0) return false;
    if (p0 == 10) return true;
    if (p0 == 172 && p1 >= 16 && p1 <= 31) return true;
    if (p0 == 192 && p1 == 168) return true;
    if (p0 == 100 && p1 >= 64 && p1 <= 127) return true;
    if (p0 == 169 && p1 == 254) return true;

    return false;
  }

  /// Filters out cellular / public / IPv6 link-local and maps loopback (127.0.0.1) to verified private LAN IP
  static String? sanitizeCandidate(String? candidate, String? fallbackIp) {
    if (candidate == null || candidate.trim().isEmpty) return null;

    final lower = candidate.toLowerCase();

    // 1. Discard IPv6 localhost and link-local candidates
    if (lower.contains('::1') ||
        lower.contains('fe80:') ||
        lower.contains('localhost')) {
      return null;
    }

    // 2. Discard mobile cellular interface keywords
    if (lower.contains('rmnet') ||
        lower.contains('ccmni') ||
        lower.contains('pdp') ||
        lower.contains('wwan') ||
        lower.contains('dummy')) {
      return null;
    }

    var cand = candidate;

    // 3. Handle mDNS .local hostname resolution if present
    if (cand.contains('.local') && fallbackIp != null && isPrivateIPv4(fallbackIp)) {
      cand = cand.replaceAll(RegExp(r'[a-zA-Z0-9_\.\-]+\.local'), fallbackIp);
    }

    // 4. If candidate contains 127.0.0.1 or 0.0.0.0, remap to known private LAN IP
    if (cand.contains('127.0.0.1') || cand.contains('0.0.0.0')) {
      if (fallbackIp != null && isPrivateIPv4(fallbackIp)) {
        cand = cand.replaceAll('127.0.0.1', fallbackIp).replaceAll('0.0.0.0', fallbackIp);
      } else {
        return null;
      }
    }

    // 5. Verify candidate IP is a valid private IPv4 address
    final match = _ipv4Pattern.firstMatch(cand);
    if (match != null) {
      final ip = match.group(0)!;
      if (!isPrivateIPv4(ip)) {
        if (fallbackIp != null && isPrivateIPv4(fallbackIp)) {
          cand = cand.replaceAll(ip, fallbackIp);
        } else {
          return null;
        }
      }
    }

    return cand;
  }

  /// Detects whether incoming SDP prioritized VP8 or H.264
  static CodecEngine detectCodecEngine(String? sdp) {
    if (sdp == null) return CodecEngine.vp8;
    for (final line in sdp.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('m=video ')) {
        final parts = line.split(' ');
        if (parts.length > 3 && parts[3] == '100') {
          return CodecEngine.h264;
        }
        break;
      }
    }
    return CodecEngine.vp8;
  }

  /// Sanitizes full SDP description by mapping 127.0.0.1 to valid local private IP,
  /// prioritizing chosen codec (VP8 or H.264), pacing decoder frames, and enabling PLI/NACK feedback
  static String sanitizeSdp(
    String? sdp,
    String? localIp, {
    int bitrateKbps = 4000,
    CodecEngine codecEngine = CodecEngine.vp8,
  }) {
    if (sdp == null || sdp.isEmpty) return '';

    final lines = sdp.split(RegExp(r'\r?\n'));
    final filteredLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('a=candidate:')) {
        final lower = line.toLowerCase();
        if (lower.contains('::1') ||
            lower.contains('fe80:') ||
            lower.contains('localhost') ||
            lower.contains('rmnet') ||
            lower.contains('ccmni') ||
            lower.contains('pdp')) {
          continue; // Drop non-routable / cellular candidate line
        }
      }

      var sanitizedLine = line;
      if (localIp != null && isPrivateIPv4(localIp)) {
        sanitizedLine = sanitizedLine
            .replaceAll('127.0.0.1', localIp)
            .replaceAll('0.0.0.0', localIp)
            .replaceAll(RegExp(r'[a-zA-Z0-9_\.\-]+\.local'), localIp);
      }

      // Prioritize chosen codec engine in m=video line
      if (sanitizedLine.startsWith('m=video ')) {
        final parts = sanitizedLine.split(' ');
        if (parts.length > 3) {
          final prefix = parts.sublist(0, 3).join(' ');
          final payloads = parts.sublist(3);
          if (codecEngine == CodecEngine.vp8) {
            if (payloads.contains('96')) {
              payloads.remove('96');
              payloads.insert(0, '96');
            }
            if (payloads.contains('97')) {
              payloads.remove('97');
              payloads.insert(1, '97');
            }
          } else {
            if (payloads.contains('100')) {
              payloads.remove('100');
              payloads.insert(0, '100');
            }
            if (payloads.contains('102')) {
              payloads.remove('102');
              payloads.insert(1, '102');
            }
          }
          sanitizedLine = '$prefix ${payloads.join(' ')}';
        }
      }

      // Add instant start bitrate to VP8 to eliminate the 45-second ramp-up delay
      if (sanitizedLine.startsWith('a=rtpmap:96 VP8/90000')) {
        final minB = (bitrateKbps * 0.7).toInt();
        final startB = (bitrateKbps * 0.9).toInt();
        filteredLines.add(sanitizedLine);
        filteredLines.add(
          'a=fmtp:96 x-google-min-bitrate=$minB;x-google-start-bitrate=$startB;x-google-max-bitrate=$bitrateKbps',
        );
        continue;
      }

      // Standardize H.264 fmtp into Hardware Level 4.0 Baseline (42e028) as backup
      if (sanitizedLine.startsWith('a=fmtp:100 ')) {
        final minB = (bitrateKbps * 0.7).toInt();
        final startB = (bitrateKbps * 0.9).toInt();
        sanitizedLine =
            'a=fmtp:100 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e028;x-google-min-bitrate=$minB;x-google-start-bitrate=$startB;x-google-max-bitrate=$bitrateKbps';
      }

      filteredLines.add(sanitizedLine);

      // Inject bandwidth limits and RTCP feedback for both VP8 (96) and H.264 (100)
      if (sanitizedLine.startsWith('m=video ')) {
        filteredLines.add('b=AS:$bitrateKbps');
        filteredLines.add('b=TIAS:${bitrateKbps * 1000}');
        filteredLines.add('a=playout-delay:0 15');
        filteredLines.add('a=rtcp-fb:96 nack');
        filteredLines.add('a=rtcp-fb:96 nack pli');
        filteredLines.add('a=rtcp-fb:96 goog-remb');
        filteredLines.add('a=rtcp-fb:96 transport-cc');
        filteredLines.add('a=rtcp-fb:100 nack');
        filteredLines.add('a=rtcp-fb:100 nack pli');
        filteredLines.add('a=rtcp-fb:100 goog-remb');
        filteredLines.add('a=rtcp-fb:100 transport-cc');
      }
    }

    return filteredLines.join('\r\n');
  }
}
