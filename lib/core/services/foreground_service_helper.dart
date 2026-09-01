import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ForegroundServiceHelper {
  ForegroundServiceHelper._();

  static const MethodChannel _channel = MethodChannel(
    'com.laithmh.hotspot_screen_sharing/foreground_service',
  );

  static final StreamController<void> _stopEventController =
      StreamController<void>.broadcast();

  static Stream<void> get onStopEvent => _stopEventController.stream;
  static bool _handlerInitialized = false;

  static void initialize() {
    if (_handlerInitialized) return;
    _handlerInitialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenShareStopped') {
        debugPrint('[ForegroundServiceHelper] Received onScreenShareStopped from Android native');
        _stopEventController.add(null);
      }
    });
  }

  static Future<bool> startService() async {
    if (!Platform.isAndroid) return true;
    initialize();

    try {
      final result = await _channel.invokeMethod<bool>('startService');
      debugPrint('[ForegroundServiceHelper] startService returned: $result');
      return result ?? false;
    } catch (e) {
      debugPrint(
        '[ForegroundServiceHelper] Error starting native foreground service: $e',
      );
      return false;
    }
  }

  static Future<bool> stopService() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('stopService');
      debugPrint('[ForegroundServiceHelper] stopService returned: $result');
      return result ?? false;
    } catch (e) {
      debugPrint(
        '[ForegroundServiceHelper] Error stopping native foreground service: $e',
      );
      return false;
    }
  }

  /// Sets screen keep-awake flag to prevent display sleep during casting
  static Future<bool> setKeepScreenOn(bool keepOn) async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('setKeepScreenOn', {
        'keepOn': keepOn,
      });
      debugPrint(
        '[ForegroundServiceHelper] setKeepScreenOn($keepOn) returned: $result',
      );
      return result ?? false;
    } catch (e) {
      debugPrint(
        '[ForegroundServiceHelper] Error setting keep screen on ($keepOn): $e',
      );
      return false;
    }
  }

  /// Binds the Android application process to the Wi-Fi/Hotspot network interface
  /// ensuring sockets route over Wi-Fi instead of Cellular Mobile Data when offline.
  static Future<bool> bindToWifiNetwork() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('bindToWifiNetwork');
      debugPrint(
        '[ForegroundServiceHelper] bindToWifiNetwork returned: $result',
      );
      return result ?? false;
    } catch (e) {
      debugPrint(
        '[ForegroundServiceHelper] Error binding process to Wi-Fi network: $e',
      );
      return false;
    }
  }
}
