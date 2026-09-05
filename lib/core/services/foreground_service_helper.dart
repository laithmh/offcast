import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ForegroundServiceHelper {
  ForegroundServiceHelper._();

  static const MethodChannel _channel = MethodChannel(
    'com.laithmh.offcast/foreground_service',
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
        debugPrint(
          '[ForegroundServiceHelper] Received onScreenShareStopped from Android native',
        );
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

  /// Starts a high-priority native UDP socket relay with 2 MB buffer in Android OS space
  static Future<int?> startNativeUdpRelay({
    required int targetLoopbackPort,
    String? remotePeerIp,
  }) async {
    if (!Platform.isAndroid) return null;

    try {
      final port = await _channel.invokeMethod<int>('startNativeUdpRelay', {
        'targetLoopbackPort': targetLoopbackPort,
        'remotePeerIp': remotePeerIp,
      });
      debugPrint(
        '[ForegroundServiceHelper] startNativeUdpRelay returned: $port',
      );
      return port;
    } catch (e) {
      debugPrint(
        '[ForegroundServiceHelper] Error starting native UDP relay: $e',
      );
      return null;
    }
  }

  /// Stops the native UDP socket relay thread and closes socket
  static Future<bool> stopNativeUdpRelay() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('stopNativeUdpRelay');
      debugPrint(
        '[ForegroundServiceHelper] stopNativeUdpRelay returned: $result',
      );
      return result ?? false;
    } catch (e) {
      debugPrint(
        '[ForegroundServiceHelper] Error stopping native UDP relay: $e',
      );
      return false;
    }
  }

  /// Reads physical battery/chassis temperature and OS thermal throttling state
  static Future<DeviceThermalInfo?> getDeviceThermalInfo() async {
    if (!Platform.isAndroid) return null;

    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'getDeviceThermalInfo',
      );
      if (res == null) return null;
      final temp = (res['temperatureC'] as num?)?.toDouble();
      final status = res['thermalStatus'] as String? ?? 'NORMAL';
      final name = res['deviceName'] as String? ?? 'Device';
      return DeviceThermalInfo(
        temperatureC: temp,
        thermalStatus: status,
        deviceName: name,
      );
    } catch (e) {
      debugPrint(
        '[ForegroundServiceHelper] Error getting device thermal info: $e',
      );
      return null;
    }
  }

  /// Gets the real manufacturer and model of this device
  static Future<String> getDeviceName() async {
    if (!Platform.isAndroid) return 'Device';

    try {
      final name = await _channel.invokeMethod<String>('getDeviceName');
      return name ?? 'Android Device';
    } catch (_) {
      return 'Android Device';
    }
  }
}

class DeviceThermalInfo {
  final double? temperatureC;
  final String thermalStatus;
  final String deviceName;

  const DeviceThermalInfo({
    this.temperatureC,
    this.thermalStatus = 'NORMAL',
    this.deviceName = 'Device',
  });
}
