import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Metrics computed from a WebRTC StatsReport delta
class CalculatedRtcMetrics {
  final double fps;
  final int latencyMs;
  final double bitrateMbps;
  final int width;
  final int height;

  const CalculatedRtcMetrics({
    required this.fps,
    required this.latencyMs,
    required this.bitrateMbps,
    required this.width,
    required this.height,
  });
}

/// Helper to calculate real-time video streaming stats (FPS, Bitrate, RTT)
/// from WebRTC StatsReports for both Sender and Receiver.
class WebRtcStatsCalculator {
  int _lastBytes = 0;
  int _lastFrames = 0;
  DateTime _lastTime = DateTime.now();

  void reset() {
    _lastBytes = 0;
    _lastFrames = 0;
    _lastTime = DateTime.now();
  }

  /// Calculates outbound RTP stats for Sender video pipeline
  CalculatedRtcMetrics calculateOutbound(
    List<StatsReport> reports, {
    int fallbackWidth = 1280,
    int fallbackHeight = 720,
  }) {
    double currentFps = 0.0;
    int rtt = 0;
    double bitrateMbps = 0.0;
    int width = fallbackWidth;
    int height = fallbackHeight;
    final now = DateTime.now();

    for (final report in reports) {
      final values = report.values;

      if (report.type == 'outbound-rtp' && values['kind'] == 'video') {
        final framesEncoded =
            int.tryParse(values['framesEncoded']?.toString() ?? '') ?? 0;
        final bytesSent =
            int.tryParse(values['bytesSent']?.toString() ?? '') ?? 0;
        final timeDelta =
            now.difference(_lastTime).inMilliseconds / 1000.0;

        if (timeDelta > 0) {
          if (_lastFrames > 0 && framesEncoded >= _lastFrames) {
            currentFps = (framesEncoded - _lastFrames) / timeDelta;
          }
          if (_lastBytes > 0 && bytesSent >= _lastBytes) {
            final bits = (bytesSent - _lastBytes) * 8;
            bitrateMbps = (bits / timeDelta) / 1000000.0;
          }
        }
        _lastFrames = framesEncoded;
        _lastBytes = bytesSent;

        final w = int.tryParse(values['frameWidth']?.toString() ?? '') ?? 0;
        final h = int.tryParse(values['frameHeight']?.toString() ?? '') ?? 0;
        if (w > 0 && h > 0) {
          width = w;
          height = h;
        }
      }

      if (report.type == 'remote-inbound-rtp' && values['kind'] == 'video') {
        final roundTripTime = (values['roundTripTime'] as num?)?.toDouble();
        if (roundTripTime != null && roundTripTime > 0) {
          rtt = (roundTripTime * 1000).toInt();
        }
      }

      if (report.type == 'candidate-pair' &&
          (values['nominated'] == true || values['state'] == 'succeeded')) {
        final roundTripTime =
            (values['currentRoundTripTime'] as num?)?.toDouble();
        if (roundTripTime != null && roundTripTime > 0 && rtt == 0) {
          rtt = (roundTripTime * 1000).toInt();
        }
      }
    }

    _lastTime = now;
    return CalculatedRtcMetrics(
      fps: currentFps,
      latencyMs: rtt,
      bitrateMbps: bitrateMbps,
      width: width,
      height: height,
    );
  }

  /// Calculates inbound RTP stats for Receiver video pipeline
  CalculatedRtcMetrics calculateInbound(
    List<StatsReport> reports, {
    int fallbackWidth = 1280,
    int fallbackHeight = 720,
  }) {
    double currentFps = 0.0;
    int rtt = 6;
    double bitrateMbps = 0.0;
    int width = fallbackWidth;
    int height = fallbackHeight;
    final now = DateTime.now();

    for (final report in reports) {
      final values = report.values;

      if (report.type == 'inbound-rtp' && values['kind'] == 'video') {
        final framesDecoded =
            int.tryParse(values['framesDecoded']?.toString() ?? '') ?? 0;
        final bytesReceived =
            int.tryParse(values['bytesReceived']?.toString() ?? '') ?? 0;
        final timeDelta =
            now.difference(_lastTime).inMilliseconds / 1000.0;

        if (timeDelta > 0) {
          if (_lastFrames > 0 && framesDecoded >= _lastFrames) {
            currentFps = (framesDecoded - _lastFrames) / timeDelta;
          }
          if (_lastBytes > 0 && bytesReceived >= _lastBytes) {
            final bits = (bytesReceived - _lastBytes) * 8;
            bitrateMbps = (bits / timeDelta) / 1000000.0;
          }
        }
        _lastFrames = framesDecoded;
        _lastBytes = bytesReceived;

        final w = int.tryParse(values['frameWidth']?.toString() ?? '') ?? 0;
        final h = int.tryParse(values['frameHeight']?.toString() ?? '') ?? 0;
        if (w > 0 && h > 0) {
          width = w;
          height = h;
        }
      }

      if (report.type == 'candidate-pair' &&
          (values['nominated'] == true || values['state'] == 'succeeded')) {
        final roundTripTime =
            (values['currentRoundTripTime'] as num?)?.toDouble();
        if (roundTripTime != null && roundTripTime > 0) {
          rtt = (roundTripTime * 1000).toInt();
        }
      }
    }

    _lastTime = now;
    return CalculatedRtcMetrics(
      fps: currentFps,
      latencyMs: rtt,
      bitrateMbps: bitrateMbps,
      width: width,
      height: height,
    );
  }
}
