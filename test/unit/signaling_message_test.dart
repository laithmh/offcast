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

      // Prompter command
      final cmd = SignalingMessage.prompterCommand(
        action: 'set_speed',
        params: {'speedWpm': 180.0},
      );
      final decodedCmd = SignalingMessage.deserialize(cmd.serialize());
      expect(decodedCmd?.type, 'prompter_command');
      expect(decodedCmd?.payload?['action'], 'set_speed');
      expect(decodedCmd?.payload?['speedWpm'], 180.0);

      // Prompter script update
      final scriptUpdate = SignalingMessage.prompterScriptUpdate(
        text: 'Welcome back to our tech review channel!',
        title: 'Tech Review Script',
      );
      final decodedScript = SignalingMessage.deserialize(
        scriptUpdate.serialize(),
      );
      expect(decodedScript?.type, 'prompter_script_update');
      expect(
        decodedScript?.payload?['text'],
        'Welcome back to our tech review channel!',
      );
      expect(decodedScript?.payload?['title'], 'Tech Review Script');

      // Prompter state sync
      final stateSync = SignalingMessage.prompterStateSync({
        'isPlaying': true,
        'scrollSpeedWpm': 140.0,
        'fontSize': 34.0,
        'isVoiceActivated': true,
      });
      final decodedSync = SignalingMessage.deserialize(stateSync.serialize());
      expect(decodedSync?.type, 'prompter_state_sync');
      expect(decodedSync?.payload?['isPlaying'], isTrue);
      expect(decodedSync?.payload?['scrollSpeedWpm'], 140.0);
    });
  });

  group('WebRTCConstants & Candidate Sanitizer Tests', () {
    test('Verify screen constraints configuration', () {
      expect(WebRTCConstants.displayMediaConstraints['audio'], false);
      expect(WebRTCConstants.displayMediaConstraints['video'], isNotNull);
    });

    test('Verify quality preset constraint configurations', () {
      final coolConstraints = WebRTCConstants.getDisplayMediaConstraints(
        preset: StreamingQualityPreset.cool540p30,
      );
      final mandatory = (coolConstraints['video'] as Map)['mandatory'] as Map;
      expect(mandatory['maxWidth'], 540);
      expect(mandatory['maxFrameRate'], 30);

      const perfStats = StreamPerformanceStats(
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
      expect(
        SdpCandidateSanitizer.sanitizeCandidate(cellularCand, '192.168.43.1'),
        isNull,
      );

      // Remapping loopback candidates to active private LAN IP
      const loopbackCand =
          'candidate:2 1 UDP 2122260223 127.0.0.1 50000 typ host';
      final sanitizedLoopback = SdpCandidateSanitizer.sanitizeCandidate(
        loopbackCand,
        '192.168.43.1',
      );
      expect(sanitizedLoopback, contains('192.168.43.1'));
      expect(sanitizedLoopback, contains('50000'));

      // Keeping valid LAN host candidate
      const validLanCand =
          'candidate:3 1 UDP 2122260223 192.168.43.1 50000 typ host';
      expect(
        SdpCandidateSanitizer.sanitizeCandidate(validLanCand, '192.168.43.1'),
        equals(validLanCand),
      );
    });

    test('Verify zero-STUN ICE configuration', () {
      final iceServers = WebRTCConstants.rtcConfiguration['iceServers'] as List;
      expect(iceServers, isEmpty);
      expect(WebRTCConstants.rtcConfiguration['sdpSemantics'], 'unified-plan');
    });

    test('Token-based candidate sanitizer preserves priority and foundation numbers', () {
      // Candidate with priority that has digits matching IP octets
      const candidateStr =
          'candidate:192 1 UDP 19216811 127.0.0.1 54321 typ host generation 0';
      final sanitized = SdpCandidateSanitizer.sanitizeCandidate(
        candidateStr,
        '192.168.43.5',
      );
      expect(sanitized, isNotNull);
      final tokens = sanitized!.split(' ');
      expect(tokens[0], 'candidate:192'); // foundation preserved
      expect(tokens[3], '19216811'); // priority preserved
      expect(tokens[4], '192.168.43.5'); // connection address remapped
      expect(tokens[5], '54321'); // port preserved
    });

    test(
      'Dynamic SDP payload detection and prioritization for VP8 and H264',
      () {
        const dynamicSdp =
            'v=0\r\nm=video 9 UDP/TLS/RTP/SAVPF 98 102\r\n'
            'a=rtpmap:98 VP8/90000\r\n'
            'a=rtpmap:102 H264/90000\r\n';

        // When VP8 chosen, 98 should be prioritized
        final sanitizedVp8 = SdpCandidateSanitizer.sanitizeSdp(
          dynamicSdp,
          '192.168.43.1',
          bitrateKbps: 3000,
          codecEngine: CodecEngine.vp8,
        );
        expect(sanitizedVp8, contains('m=video 9 UDP/TLS/RTP/SAVPF 98 102'));
        expect(sanitizedVp8, contains('a=fmtp:98'));
        expect(sanitizedVp8, contains('a=rtcp-fb:98 nack pli'));

        // When H264 chosen, 102 should be prioritized first
        final sanitizedH264 = SdpCandidateSanitizer.sanitizeSdp(
          dynamicSdp,
          '192.168.43.1',
          bitrateKbps: 3000,
          codecEngine: CodecEngine.h264,
        );
        expect(sanitizedH264, contains('m=video 9 UDP/TLS/RTP/SAVPF 102 98'));
        expect(sanitizedH264, contains('a=fmtp:102'));
        expect(sanitizedH264, contains('a=rtcp-fb:102 nack pli'));
        expect(sanitizedH264, contains('a=playout-delay:0 0'));
      },
    );

    test('Auth and AuthResponse message serialization and deserialization', () {
      final authMsg = SignalingMessage.auth(pin: '4829');
      expect(authMsg.type, 'auth');
      expect(authMsg.payload?['pin'], '4829');

      final authDecoded = SignalingMessage.deserialize(authMsg.serialize());
      expect(authDecoded?.type, 'auth');
      expect(authDecoded?.payload?['pin'], '4829');

      final authRespSuccess = SignalingMessage.authResponse(success: true);
      final respDecoded = SignalingMessage.deserialize(authRespSuccess.serialize());
      expect(respDecoded?.type, 'auth_response');
      expect(respDecoded?.payload?['success'], true);

      final authRespFail = SignalingMessage.authResponse(
        success: false,
        reason: 'Invalid pairing PIN',
      );
      final failDecoded = SignalingMessage.deserialize(authRespFail.serialize());
      expect(failDecoded?.type, 'auth_response');
      expect(failDecoded?.payload?['success'], false);
      expect(failDecoded?.payload?['reason'], 'Invalid pairing PIN');
    });

    test('SignalingMessage handles malformed JSON without crashing', () {
      // Non-map payload and candidate
      final malformed = SignalingMessage.fromJson({
        'type': 'test',
        'payload': 'not-a-map',
        'candidate': 12345,
      });
      expect(malformed.type, 'test');
      expect(malformed.payload, isNull);
      expect(malformed.candidate, isNull);

      // Deserialization of invalid string
      expect(SignalingMessage.deserialize('not a json'), isNull);
      expect(SignalingMessage.deserialize('[]'), isNull);
    });
  });
}
