import 'package:flutter_test/flutter_test.dart';
import 'package:hotspot_screen_sharing/core/network/discovery_beacon.dart';

void main() {
  group('DiscoveryBeacon Security & Parsing Tests', () {
    test('DiscoveredDevice accepts valid private IPv4 and port', () {
      final json = {
        'ip': '192.168.43.1',
        'port': 8080,
        'service': 'hotspot_screen_sharing',
        'name': 'Android Monitor',
      };
      final device = DiscoveredDevice.fromJson(json, '192.168.43.1');

      expect(device.ip, '192.168.43.1');
      expect(device.port, 8080);
      expect(device.deviceName, 'Android Monitor');
      expect(device.wsUrl, 'ws://192.168.43.1:8080');
    });

    test('DiscoveredDevice falls back to sender IP when claimed IP is public or spoofed', () {
      final json = {
        'ip': '8.8.8.8', // Public / external IP spoofed
        'port': 8080,
        'service': 'hotspot_screen_sharing',
        'name': 'Spoofed Device',
      };
      final device = DiscoveredDevice.fromJson(json, '192.168.43.50');

      // Must reject 8.8.8.8 and fall back to verified packet sender IP
      expect(device.ip, '192.168.43.50');
    });

    test(
      'DiscoveredDevice falls back to default port 8080 on invalid port values',
      () {
        final jsonNegative = {'ip': '192.168.43.1', 'port': -1};
        expect(
          DiscoveredDevice.fromJson(jsonNegative, '192.168.43.1').port,
          8080,
        );

        final jsonOverflow = {'ip': '192.168.43.1', 'port': 70000};
        expect(
          DiscoveredDevice.fromJson(jsonOverflow, '192.168.43.1').port,
          8080,
        );
      },
    );
  });
}
