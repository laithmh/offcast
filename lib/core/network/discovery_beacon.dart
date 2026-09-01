import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../constants/webrtc_constants.dart';

class DiscoveredDevice {
  final String ip;
  final int port;
  final String service;
  final String deviceName;
  final DateTime lastSeen;
  final bool isVerified;

  const DiscoveredDevice({
    required this.ip,
    required this.port,
    required this.service,
    required this.deviceName,
    required this.lastSeen,
    this.isVerified = false,
  });

  String get wsUrl => 'ws://$ip:$port';

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json, String senderIp) {
    return DiscoveredDevice(
      ip: json['ip'] as String? ?? senderIp,
      port: json['port'] as int? ?? 8080,
      service: json['service'] as String? ?? 'hotspot_screen_sharing',
      deviceName: json['name'] as String? ?? 'Receiver Device',
      lastSeen: DateTime.now(),
      isVerified: true,
    );
  }
}

class DiscoveryBroadcaster {
  static const int broadcastPort = 8888;
  static const String serviceName = 'hotspot_screen_sharing';

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;

  Future<void> start({
    required String localIp,
    required int signalingPort,
    String? deviceName,
  }) async {
    await stop();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;

      final targets = <String>{
        '255.255.255.255',
        if (NetworkHelper.calculateSubnetBroadcast(localIp) != null)
          NetworkHelper.calculateSubnetBroadcast(localIp)!,
        ...await NetworkHelper.getBroadcastAddresses(),
      };

      final payload = utf8.encode(
        jsonEncode({
          'service': serviceName,
          'ip': localIp,
          'port': signalingPort,
          'name': deviceName ?? 'Receiver (${Platform.operatingSystem})',
        }),
      );

      void sendAll() {
        if (_socket == null) return;
        for (final target in targets) {
          try {
            _socket!.send(payload, InternetAddress(target), broadcastPort);
          } catch (_) {}
        }
      }

      sendAll();
      _broadcastTimer = Timer.periodic(const Duration(seconds: 1), (_) => sendAll());
    } catch (e) {
      debugPrint('[DiscoveryBroadcaster] Failed to start UDP broadcaster: $e');
    }
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _socket?.close();
    _socket = null;
  }
}

class DiscoveryListener {
  static const int broadcastPort = 8888;
  static const String serviceName = 'hotspot_screen_sharing';

  RawDatagramSocket? _socket;
  final StreamController<DiscoveredDevice> _deviceController =
      StreamController<DiscoveredDevice>.broadcast();

  Stream<DiscoveredDevice> get discoveredDevices => _deviceController.stream;

  Future<void> start() async {
    await stop();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        broadcastPort,
        reuseAddress: true,
      );

      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            try {
              final json = jsonDecode(utf8.decode(datagram.data));
              if (json is Map<String, dynamic> && json['service'] == serviceName) {
                _deviceController.add(
                  DiscoveredDevice.fromJson(json, datagram.address.address),
                );
              }
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      debugPrint('[DiscoveryListener] Failed to start UDP listener: $e');
    }
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
  }

  Future<void> dispose() async {
    await stop();
    await _deviceController.close();
  }
}

class NetworkHelper {
  NetworkHelper._();

  /// Probes if a TCP port is open
  static Future<bool> probePort(
    String ip,
    int port, {
    Duration timeout = const Duration(milliseconds: 300),
  }) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      await socket.close();
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns client primary local IPv4 address
  static Future<String?> getMyDeviceIp() async {
    final ips = await getAllLocalIps();
    return ips.isNotEmpty ? ips.first : null;
  }

  /// Returns matching local IP based on peer subnet prefix
  static Future<String?> findBestMatchingLocalIp(String? peerIp) async {
    final allIps = await getAllLocalIps();
    if (allIps.isEmpty) return null;
    if (peerIp == null || peerIp.isEmpty) return allIps.first;

    final parts = peerIp.split('.');
    if (parts.length == 4) {
      final p24 = '${parts[0]}.${parts[1]}.${parts[2]}.';
      final p16 = '${parts[0]}.${parts[1]}.';
      for (final ip in allIps) {
        if (ip.startsWith(p24)) return ip;
      }
      for (final ip in allIps) {
        if (ip.startsWith(p16)) return ip;
      }
    }
    return allIps.first;
  }

  /// Returns all active private IPv4 addresses, prioritizing Wi-Fi/Hotspot over Cellular
  static Future<List<String>> getAllLocalIps() async {
    final wifiIps = <String>{};
    final otherIps = <String>{};

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        final isCellular = name.contains('rmnet') ||
            name.contains('ccmni') ||
            name.contains('pdp') ||
            name.contains('wwan') ||
            name.contains('radio') ||
            name.contains('dummy');

        for (final addr in iface.addresses) {
          if (SdpCandidateSanitizer.isPrivateIPv4(addr.address)) {
            if (!isCellular) {
              wifiIps.add(addr.address);
            } else {
              otherIps.add(addr.address);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[NetworkHelper] Error getting local IPs: $e');
    }

    return wifiIps.isNotEmpty ? wifiIps.toList() : otherIps.toList();
  }

  /// Actively probes candidate IPs and local subnet for an active port 8080 receiver
  static Future<String?> scanSubnetForSignalingServer({
    int port = 8080,
    void Function(String ip)? onFound,
  }) async {
    final localIps = await getAllLocalIps();
    if (localIps.isEmpty) return null;

    final priorityIps = <String>{'192.168.43.1', '172.20.10.1'};
    for (final ip in localIps) {
      final parts = ip.split('.');
      if (parts.length == 4) {
        priorityIps.add('${parts[0]}.${parts[1]}.${parts[2]}.1');
        priorityIps.add('${parts[0]}.${parts[1]}.${parts[2]}.254');
      }
    }

    // Fast probe priority gateways
    for (final ip in priorityIps) {
      if (await probePort(ip, port, timeout: const Duration(milliseconds: 250))) {
        onFound?.call(ip);
        return ip;
      }
    }

    // Fast parallel subnet sweep
    for (final ip in localIps) {
      final parts = ip.split('.');
      if (parts.length != 4) continue;
      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';

      final hosts = [for (int i = 2; i <= 254; i++) '$prefix.$i'];
      const chunkSize = 40;
      for (int i = 0; i < hosts.length; i += chunkSize) {
        final chunk = hosts.skip(i).take(chunkSize);
        final results = await Future.wait(
          chunk.map((h) async => MapEntry(h, await probePort(h, port))),
        );
        for (final res in results) {
          if (res.value) {
            onFound?.call(res.key);
            return res.key;
          }
        }
      }
    }

    return null;
  }

  /// Deduced Hotspot Host/Gateway IP
  static Future<String?> detectHotspotGatewayIp() async {
    final myIp = await getMyDeviceIp();
    if (myIp != null) {
      final parts = myIp.split('.');
      if (parts.length == 4) {
        return parts[3] == '1' ? myIp : '${parts[0]}.${parts[1]}.${parts[2]}.1';
      }
    }
    return null;
  }

  static Future<Set<String>> getBroadcastAddresses() async {
    final broadcasts = <String>{};
    for (final ip in await getAllLocalIps()) {
      final bcast = calculateSubnetBroadcast(ip);
      if (bcast != null) broadcasts.add(bcast);
    }
    return broadcasts;
  }

  static String? calculateSubnetBroadcast(String ip) {
    final parts = ip.split('.');
    return parts.length == 4 ? '${parts[0]}.${parts[1]}.${parts[2]}.255' : null;
  }
}
