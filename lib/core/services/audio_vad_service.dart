import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VadEvent {
  final bool isSpeaking;
  final double decibels;
  final double audioLevel;

  const VadEvent({
    required this.isSpeaking,
    this.decibels = -100.0,
    this.audioLevel = 0.0,
  });

  @override
  String toString() =>
      'VadEvent(isSpeaking: $isSpeaking, dB: ${decibels.toStringAsFixed(1)}, level: ${(audioLevel * 100).toStringAsFixed(0)}%)';
}

class AudioVadService {
  static const EventChannel _eventChannel =
      EventChannel('com.laithmh.hotspot_screen_sharing/audio_vad');
  static const MethodChannel _methodChannel =
      MethodChannel('com.laithmh.hotspot_screen_sharing/foreground_service');

  final StreamController<VadEvent> _vadController =
      StreamController<VadEvent>.broadcast();
  StreamSubscription? _eventSubscription;

  bool _isRunning = false;
  bool _isSpeaking = false;
  double _currentDecibels = -100.0;
  double _currentLevel = 0.0;

  bool get isRunning => _isRunning;
  bool get isSpeaking => _isSpeaking;
  double get currentDecibels => _currentDecibels;
  double get currentLevel => _currentLevel;
  Stream<VadEvent> get vadStream => _vadController.stream;

  /// Starts offline Voice Activity Detection
  Future<void> start() async {
    if (_isRunning) return;

    if (Platform.isAndroid) {
      try {
        _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
          (dynamic raw) {
            if (raw is Map) {
              final speaking = raw['isSpeaking'] as bool? ?? false;
              final db = (raw['decibels'] as num?)?.toDouble() ?? -100.0;
              final level = (raw['audioLevel'] as num?)?.toDouble() ?? 0.0;

              _isSpeaking = speaking;
              _currentDecibels = db;
              _currentLevel = level;

              final event = VadEvent(
                isSpeaking: speaking,
                decibels: db,
                audioLevel: level,
              );
              _vadController.add(event);
            }
          },
          onError: (dynamic error) {
            debugPrint('[AudioVadService] Native VAD stream error: $error');
          },
        );
        _isRunning = true;
      } catch (e) {
        debugPrint('[AudioVadService] Error starting native VAD: $e');
      }
    } else {
      // Mock mode for testing / desktop
      _isRunning = true;
      _vadController.add(
        const VadEvent(isSpeaking: true, decibels: -30.0, audioLevel: 0.4),
      );
    }
  }

  /// Sets speech activation threshold in dB (default -42.0 dB)
  Future<void> setThreshold(double thresholdDb) async {
    if (Platform.isAndroid) {
      try {
        await _methodChannel.invokeMethod('setVadThreshold', {
          'threshold': thresholdDb,
        });
      } catch (e) {
        debugPrint('[AudioVadService] Failed to set VAD threshold: $e');
      }
    }
  }

  /// Stops voice activity detection and releases mic resources
  Future<void> stop() async {
    _isRunning = false;
    _isSpeaking = false;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  Future<void> dispose() async {
    await stop();
    await _vadController.close();
  }
}
