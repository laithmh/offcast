enum StreamingQualityPreset {
  ultra1080p60(
    label: 'Ultra (720x1600 @ 60 FPS)',
    description: 'Crisp 60 FPS smooth motion for gaming & scrolling',
    targetFps: 60,
    maxWidth: 720,
    maxHeight: 1600,
    bitrateKbps: 5500,
  ),
  balanced720p30(
    label: 'Balanced (720x1600 @ 30 FPS)',
    description: 'Smooth navigation with low battery and cool temperature',
    targetFps: 30,
    maxWidth: 720,
    maxHeight: 1600,
    bitrateKbps: 3500,
  ),
  performance540p30(
    label: 'Performance (540x1200 @ 60 FPS)',
    description: 'Ultra-low latency & zero heat for budget devices',
    targetFps: 60,
    maxWidth: 540,
    maxHeight: 1200,
    bitrateKbps: 2500,
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

  const StreamPerformanceStats({
    this.fps = 0.0,
    this.latencyMs = 0,
    this.bitrateMbps = 0.0,
    this.width = 0,
    this.height = 0,
  });

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

  /// Screen capture constraints optimized for 16-pixel aligned display ratios
  static Map<String, dynamic> getDisplayMediaConstraints({
    StreamingQualityPreset preset = StreamingQualityPreset.balanced720p30,
  }) {
    return {
      'audio': false,
      'video': {
        'mandatory': {
          'minWidth': '${preset.maxWidth}',
          'maxWidth': '${preset.maxWidth}',
          'minHeight': '${preset.maxHeight}',
          'maxHeight': '${preset.maxHeight}',
          'minFrameRate': '${preset.targetFps}',
          'maxFrameRate': '${preset.targetFps}',
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

  /// Sanitizes full SDP description by mapping 127.0.0.1 to valid local private IP,
  /// prioritizing hardware H.264 Baseline Profile, injecting playout-delay, and dropping invalid candidates
  static String sanitizeSdp(String? sdp, String? localIp, {int bitrateKbps = 4500}) {
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

      // Prioritize H.264 payload type (100) first in m=video line
      if (sanitizedLine.startsWith('m=video ')) {
        final parts = sanitizedLine.split(' ');
        if (parts.length > 3) {
          final prefix = parts.sublist(0, 3).join(' ');
          final payloads = parts.sublist(3);
          if (payloads.contains('100')) {
            payloads.remove('100');
            payloads.insert(0, '100');
          }
          if (payloads.contains('101')) {
            payloads.remove('101');
            payloads.insert(1, '101');
          }
          sanitizedLine = '$prefix ${payloads.join(' ')}';
        }
      }

      // Lock H.264 fmtp into Hardware Baseline profile for zero B-frame latency and cool thermal operation
      if (sanitizedLine.startsWith('a=fmtp:100 ')) {
        sanitizedLine =
            '$sanitizedLine;profile-level-id=42e01f;packetization-mode=1;level-asymmetry-allowed=1;x-google-min-bitrate=2500;x-google-start-bitrate=4000;x-google-max-bitrate=10000';
      }

      filteredLines.add(sanitizedLine);

      // Inject bandwidth limits and zero-latency playout delay right after m=video line
      if (sanitizedLine.startsWith('m=video ')) {
        filteredLines.add('b=AS:$bitrateKbps');
        filteredLines.add('b=TIAS:${bitrateKbps * 1000}');
        filteredLines.add('a=playout-delay:0 0');
      }
    }

    return filteredLines.join('\r\n');
  }
}
