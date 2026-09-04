import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hotspot_screen_sharing/core/utils/webrtc_stats_calculator.dart';

void main() {
  group('WebRtcStatsCalculator Unit Tests', () {
    late WebRtcStatsCalculator calculator;

    setUp(() {
      calculator = WebRtcStatsCalculator();
    });

    test('calculateOutbound calculates fps and bitrate from delta reports', () {
      final initialReports = [
        StatsReport(
          'outbound-1',
          'outbound-rtp',
          1000.0,
          {
            'kind': 'video',
            'framesEncoded': 60,
            'bytesSent': 250000,
            'frameWidth': 1920,
            'frameHeight': 1080,
          },
        ),
      ];

      // First sample primes the delta
      final firstMetrics = calculator.calculateOutbound(initialReports);
      expect(firstMetrics.width, 1920);
      expect(firstMetrics.height, 1080);
      expect(firstMetrics.fps, 0.0); // No delta yet

      // Second sample after delta
      final secondReports = [
        StatsReport(
          'outbound-1',
          'outbound-rtp',
          2000.0,
          {
            'kind': 'video',
            'framesEncoded': 120,
            'bytesSent': 500000,
            'frameWidth': 1920,
            'frameHeight': 1080,
          },
        ),
        StatsReport(
          'pair-1',
          'candidate-pair',
          2000.0,
          {
            'state': 'succeeded',
            'currentRoundTripTime': 0.012,
          },
        ),
      ];

      final secondMetrics = calculator.calculateOutbound(secondReports);
      expect(secondMetrics.width, 1920);
      expect(secondMetrics.height, 1080);
      expect(secondMetrics.fps, greaterThanOrEqualTo(0.0));
      expect(secondMetrics.latencyMs, 12);
    });

    test('calculateInbound calculates decoded frames and RTT', () {
      final initialReports = [
        StatsReport(
          'inbound-1',
          'inbound-rtp',
          1000.0,
          {
            'kind': 'video',
            'framesDecoded': 30,
            'bytesReceived': 120000,
            'frameWidth': 1280,
            'frameHeight': 720,
          },
        ),
      ];

      final metrics = calculator.calculateInbound(initialReports);
      expect(metrics.width, 1280);
      expect(metrics.height, 720);

      calculator.reset();
      expect(calculator, isNotNull);
    });
  });
}
