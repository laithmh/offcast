import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hotspot_screen_sharing/core/constants/webrtc_constants.dart';
import 'package:hotspot_screen_sharing/core/models/signaling_message.dart';

void main() {
  group('SignalingMessage Unit Tests', () {
    test('Offer serialization and deserialization', () {
      const sdpText = 'v=0\r\no=- 12345 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n';
      final msg = SignalingMessage.offer(sdpText);

      final jsonString = msg.serialize();
      final decoded = SignalingMessage.deserialize(jsonString);

      expect(decoded, isNotNull);
      expect(decoded!.type, 'offer');
      expect(decoded.sdp, sdpText);
      expect(decoded.candidate, isNull);
    });

    test('Answer serialization and deserialization', () {
      const sdpText = 'v=0\r\no=- 67890 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n';
      final msg = SignalingMessage.answer(sdpText);

      final jsonString = msg.serialize();
      final decoded = SignalingMessage.deserialize(jsonString);

      expect(decoded, isNotNull);
      expect(decoded!.type, 'answer');
      expect(decoded.sdp, sdpText);
      expect(decoded.candidate, isNull);
    });

    test('Candidate serialization and deserialization', () {
      final iceCandidate = RTCIceCandidate(
        'candidate:842163049 1 udp 1677729535 192.168.43.1 54321 typ host',
        '0',
        0,
      );
      final msg = SignalingMessage.candidate(iceCandidate);

      final jsonString = msg.serialize();
      final decoded = SignalingMessage.deserialize(jsonString);

      expect(decoded, isNotNull);
      expect(decoded!.type, 'candidate');
      expect(decoded.candidate, isNotNull);
      expect(
        decoded.candidate!['candidate'],
        'candidate:842163049 1 udp 1677729535 192.168.43.1 54321 typ host',
      );
      expect(decoded.candidate!['sdpMid'], '0');
      expect(decoded.candidate!['sdpMLineIndex'], 0);
    });

    test('Ping, Pong, Bye, and Orientation messages serialization', () {
      final bye = SignalingMessage.bye();
      expect(SignalingMessage.deserialize(bye.serialize())?.type, 'bye');

      final ping = SignalingMessage.ping();
      expect(SignalingMessage.deserialize(ping.serialize())?.type, 'ping');

      final pong = SignalingMessage.pong();
      expect(SignalingMessage.deserialize(pong.serialize())?.type, 'pong');

      final orient = SignalingMessage.orientationChange(
        width: 1080,
        height: 2400,
        rotation: 90,
      );
      final decodedOrient = SignalingMessage.deserialize(orient.serialize());
      expect(decodedOrient?.type, 'orientation_change');
      expect(decodedOrient?.payload?['width'], 1080);
      expect(decodedOrient?.payload?['height'], 2400);
      expect(decodedOrient?.payload?['rotation'], 90);
    });
  });

  group('WebRTCConstants & Candidate Sanitizer Tests', () {
    test('Verify screen constraints and zero-audio configuration', () {
      expect(WebRTCConstants.displayMediaConstraints['audio'], false);
      expect(WebRTCConstants.displayMediaConstraints['video'], isNotNull);
    });

    test('Verify quality preset constraint configurations', () {
      final ultraConstraints = WebRTCConstants.getDisplayMediaConstraints(
        preset: StreamingQualityPreset.ultra1080p60,
      );
      final mandatory = (ultraConstraints['video'] as Map)['mandatory'] as Map;
      expect(mandatory['minFrameRate'], '60');
      expect(mandatory['maxFrameRate'], '60');

      final perfStats = const StreamPerformanceStats(
        fps: 59.8,
        latencyMs: 4,
        bitrateMbps: 8.2,
        width: 1920,
        height: 1080,
      );
      expect(perfStats.resolutionText, '1920x1080');
      expect(perfStats.fps, 59.8);
      expect(perfStats.latencyMs, 4);
    });

    test('Verify private IPv4 detection and candidate filtering', () {
      expect(SdpCandidateSanitizer.isPrivateIPv4('192.168.43.1'), isTrue);
      expect(SdpCandidateSanitizer.isPrivateIPv4('10.0.0.1'), isTrue);
      expect(SdpCandidateSanitizer.isPrivateIPv4('172.20.10.1'), isTrue);
      expect(SdpCandidateSanitizer.isPrivateIPv4('127.0.0.1'), isFalse);
      expect(SdpCandidateSanitizer.isPrivateIPv4('8.8.8.8'), isFalse);

      // Filtering out cellular interface candidate strings
      const cellularCand = 'candidate:1 1 UDP 2122260223 rmnet0 50000 typ host';
      expect(SdpCandidateSanitizer.sanitizeCandidate(cellularCand, '192.168.43.1'), isNull);

      // Remapping loopback candidates to active private LAN IP
      const loopbackCand = 'candidate:2 1 UDP 2122260223 127.0.0.1 50000 typ host';
      final sanitizedLoopback = SdpCandidateSanitizer.sanitizeCandidate(loopbackCand, '192.168.43.1');
      expect(sanitizedLoopback, contains('192.168.43.1'));
      expect(sanitizedLoopback, contains('50000'));

      // Keeping valid LAN host candidate
      const validLanCand = 'candidate:3 1 UDP 2122260223 192.168.43.1 50000 typ host';
      expect(SdpCandidateSanitizer.sanitizeCandidate(validLanCand, '192.168.43.1'), equals(validLanCand));
    });

    test('Verify zero-STUN ICE configuration', () {
      final iceServers = WebRTCConstants.rtcConfiguration['iceServers'] as List;
      expect(iceServers, isEmpty);
      expect(WebRTCConstants.rtcConfiguration['sdpSemantics'], 'unified-plan');
    });
  });
}
