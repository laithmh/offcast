import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../constants/webrtc_constants.dart';

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
    return SignalingMessage(type: 'offer', sdp: sdp);
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

  factory SignalingMessage.auth({required String pin}) {
    return SignalingMessage(type: 'auth', payload: {'pin': pin});
  }

  factory SignalingMessage.authResponse({
    required bool success,
    String? reason,
  }) {
    return SignalingMessage(
      type: 'auth_response',
      payload: {'success': success, 'reason': ?reason},
    );
  }

  factory SignalingMessage.orientationChange({
    required int width,
    required int height,
    required int rotation,
  }) {
    return SignalingMessage(
      type: 'orientation_change',
      payload: {'width': width, 'height': height, 'rotation': rotation},
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

  factory SignalingMessage.prompterCommand({
    required String action,
    Map<String, dynamic>? params,
  }) {
    return SignalingMessage(
      type: 'prompter_command',
      payload: {'action': action, ...?params},
    );
  }

  factory SignalingMessage.prompterScriptUpdate({
    required String text,
    String? title,
  }) {
    return SignalingMessage(
      type: 'prompter_script_update',
      payload: {'text': text, 'title': ?title},
    );
  }

  factory SignalingMessage.prompterStateSync(Map<String, dynamic> state) {
    return SignalingMessage(type: 'prompter_state_sync', payload: state);
  }

  factory SignalingMessage.streamMetadata({
    required StreamSourceType streamSource,
  }) {
    return SignalingMessage(
      type: 'stream_metadata',
      payload: {'streamSource': streamSource.name},
    );
  }

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? candidateMap;
    if (json['candidate'] is Map) {
      try {
        candidateMap = Map<String, dynamic>.from(json['candidate'] as Map);
      } catch (_) {}
    }

    Map<String, dynamic>? payloadMap;
    if (json['payload'] is Map) {
      try {
        payloadMap = Map<String, dynamic>.from(json['payload'] as Map);
      } catch (_) {}
    }

    return SignalingMessage(
      type: json['type'] as String? ?? 'unknown',
      sdp: json['sdp'] as String?,
      candidate: candidateMap,
      payload: payloadMap,
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
      if (decoded is Map) {
        return SignalingMessage.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }
}
