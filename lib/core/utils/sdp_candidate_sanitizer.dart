import '../constants/webrtc_constants.dart';

/// RFC 5245 & RFC 8445 candidate parsing, private IPv4 detection,
/// and dynamic SDP codec & bandwidth sanitizer.
class SdpCandidateSanitizer {
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

    // 3. Token-based candidate parsing according to RFC 5245 / RFC 8445
    // Format: [a=]candidate:<foundation> <component-id> <transport> <priority> <connection-address> <port> typ <candidate-type> ...
    final prefix = candidate.startsWith('a=') ? 'a=' : '';
    final rawLine = candidate.startsWith('a=')
        ? candidate.substring(2)
        : candidate;
    final tokens = rawLine.split(' ');

    if (tokens.length >= 6 && tokens[0].startsWith('candidate:')) {
      var connectionAddr = tokens[4];

      // Handle mDNS .local hostname resolution
      if (connectionAddr.endsWith('.local') &&
          fallbackIp != null &&
          isPrivateIPv4(fallbackIp)) {
        connectionAddr = fallbackIp;
      }

      // Remap loopback to known private LAN IP
      if (connectionAddr == '127.0.0.1' || connectionAddr == '0.0.0.0') {
        if (fallbackIp != null && isPrivateIPv4(fallbackIp)) {
          connectionAddr = fallbackIp;
        } else {
          return null;
        }
      }

      // Ensure connection address is a valid private IPv4 address
      if (!isPrivateIPv4(connectionAddr)) {
        if (fallbackIp != null && isPrivateIPv4(fallbackIp)) {
          connectionAddr = fallbackIp;
        } else {
          return null;
        }
      }

      tokens[4] = connectionAddr;
      return '$prefix${tokens.join(' ')}';
    }

    return candidate;
  }

  /// Detects whether incoming SDP prioritized VP8 or H.264
  static CodecEngine detectCodecEngine(String? sdp) {
    if (sdp == null) return CodecEngine.vp8;
    String? h264Pt;
    for (final line in sdp.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('a=rtpmap:')) {
        final parts = line.substring('a=rtpmap:'.length).trim().split(' ');
        if (parts.length >= 2 && parts[1].toUpperCase().startsWith('H264/')) {
          h264Pt = parts[0];
          break;
        }
      }
    }

    for (final line in sdp.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('m=video ')) {
        final parts = line.split(' ');
        if (parts.length > 3) {
          final firstPt = parts[3];
          if (h264Pt != null && firstPt == h264Pt) {
            return CodecEngine.h264;
          }
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

    // Detect dynamic payload types for VP8 and H264
    String? vp8Payload;
    String? h264Payload;
    for (final line in lines) {
      if (line.startsWith('a=rtpmap:')) {
        final parts = line.substring('a=rtpmap:'.length).trim().split(' ');
        if (parts.length >= 2) {
          final pt = parts[0];
          final codec = parts[1].toUpperCase();
          if (codec.startsWith('VP8/')) vp8Payload ??= pt;
          if (codec.startsWith('H264/')) h264Payload ??= pt;
        }
      }
    }
    final primaryVp8 = vp8Payload ?? '96';
    final primaryH264 = h264Payload ?? '100';

    for (final line in lines) {
      if (line.startsWith('a=candidate:')) {
        final sanitizedCand = sanitizeCandidate(line, localIp);
        if (sanitizedCand != null) {
          filteredLines.add(sanitizedCand);
        }
        continue;
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
          final preferredPt = codecEngine == CodecEngine.vp8
              ? primaryVp8
              : primaryH264;
          if (payloads.contains(preferredPt)) {
            payloads.remove(preferredPt);
            payloads.insert(0, preferredPt);
          }
          sanitizedLine = '$prefix ${payloads.join(' ')}';
        }
      }

      // Add instant start bitrate to VP8 to eliminate ramp-up delay
      if (sanitizedLine.startsWith('a=rtpmap:$primaryVp8 VP8/')) {
        final minB = (bitrateKbps * 0.7).toInt();
        final startB = (bitrateKbps * 0.9).toInt();
        filteredLines.add(sanitizedLine);
        filteredLines.add(
          'a=fmtp:$primaryVp8 x-google-min-bitrate=$minB;x-google-start-bitrate=$startB;x-google-max-bitrate=$bitrateKbps',
        );
        continue;
      }

      // Standardize H.264 fmtp into Hardware Level 4.0 Baseline (42e028)
      if (sanitizedLine.startsWith('a=rtpmap:$primaryH264 H264/')) {
        final minB = (bitrateKbps * 0.7).toInt();
        final startB = (bitrateKbps * 0.9).toInt();
        filteredLines.add(sanitizedLine);
        filteredLines.add(
          'a=fmtp:$primaryH264 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e028;x-google-min-bitrate=$minB;x-google-start-bitrate=$startB;x-google-max-bitrate=$bitrateKbps',
        );
        continue;
      }

      if (sanitizedLine.startsWith('a=fmtp:$primaryH264 ')) {
        // Skip existing fmtp line since we already injected standardized baseline
        continue;
      }

      filteredLines.add(sanitizedLine);

      // Inject bandwidth limits and RTCP feedback for both VP8 and H.264
      if (sanitizedLine.startsWith('m=video ')) {
        filteredLines.add('b=AS:$bitrateKbps');
        filteredLines.add('b=TIAS:${bitrateKbps * 1000}');
        filteredLines.add('a=playout-delay:0 15');
        filteredLines.add('a=rtcp-fb:$primaryVp8 nack');
        filteredLines.add('a=rtcp-fb:$primaryVp8 nack pli');
        filteredLines.add('a=rtcp-fb:$primaryVp8 goog-remb');
        filteredLines.add('a=rtcp-fb:$primaryVp8 transport-cc');
        filteredLines.add('a=rtcp-fb:$primaryH264 nack');
        filteredLines.add('a=rtcp-fb:$primaryH264 nack pli');
        filteredLines.add('a=rtcp-fb:$primaryH264 goog-remb');
        filteredLines.add('a=rtcp-fb:$primaryH264 transport-cc');
      }
    }

    return filteredLines.join('\r\n');
  }
}
