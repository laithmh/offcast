import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingMessage {
  final String type;
  final String? sdp;
  final Map<String, dynamic>? candidate;
  final Map<String, dynamic>? payload;

  const SignalingMessage({
    required this.type,
    this.sdp,
    this.candidate,
    this.payload,
  });

  factory SignalingMessage.offer(String sdp) {
    return SignalingMessage(
      type: 'offer',
      sdp: sdp,
    );
  }

  factory SignalingMessage.answer(String sdp) {
    return SignalingMessage(type: 'answer', sdp: sdp);
  }

  factory SignalingMessage.candidate(RTCIceCandidate iceCandidate) {
    return SignalingMessage(
      type: 'candidate',
      candidate: {
        'candidate': iceCandidate.candidate,
        'sdpMid': iceCandidate.sdpMid,
        'sdpMLineIndex': iceCandidate.sdpMLineIndex,
      },
    );
  }

  factory SignalingMessage.bye() {
    return const SignalingMessage(type: 'bye');
  }

  factory SignalingMessage.ping() {
    return const SignalingMessage(type: 'ping');
  }

  factory SignalingMessage.pong() {
    return const SignalingMessage(type: 'pong');
  }

  factory SignalingMessage.orientationChange({
    required int width,
    required int height,
    required int rotation,
  }) {
    return SignalingMessage(
      type: 'orientation_change',
      payload: {
        'width': width,
        'height': height,
        'rotation': rotation,
      },
    );
  }

  factory SignalingMessage.thermalTelemetry({
    required double? temperatureC,
    required String thermalStatus,
    String? deviceName,
  }) {
    return SignalingMessage(
      type: 'thermal_telemetry',
      payload: {
        'temperatureC': temperatureC,
        'thermalStatus': thermalStatus,
        'deviceName': deviceName,
      },
    );
  }

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type'] as String? ?? 'unknown',
      sdp: json['sdp'] as String?,
      candidate: json['candidate'] != null
          ? Map<String, dynamic>.from(json['candidate'] as Map)
          : null,
      payload: json['payload'] != null
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (sdp != null) map['sdp'] = sdp;
    if (candidate != null) map['candidate'] = candidate;
    if (payload != null) map['payload'] = payload;
    return map;
  }

  String serialize() => jsonEncode(toJson());

  static SignalingMessage? deserialize(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return SignalingMessage.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
