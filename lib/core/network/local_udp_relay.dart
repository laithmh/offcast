import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/foreground_service_helper.dart';

/// A high-performance UDP relay that bridges WebRTC loopback sockets
/// (127.0.0.1:port) with physical Wi-Fi Hotspot / LAN interfaces (0.0.0.0:port).
///
/// On Android, this delegates to NativeUdpRelay (Kotlin) running on a dedicated OS thread
/// with real-time priority (nice=-19) and a 2 MB kernel socket buffer, bypassing Dart completely.
/// Includes automatic graceful fallback to an in-process Dart socket on other platforms or if native fails.
class LocalUdpRelay {
  bool _usingNativeRelay = false;
  RawDatagramSocket? _socket;
  int? _publicPort;
  int? _targetLoopbackPort;
  InternetAddress? _remotePeerAddress;
  int? _remotePeerPort;

  int? get publicPort => _publicPort;

  /// Starts the relay listening on 0.0.0.0 and bridging to the target loopback port
  Future<int> start({
    required int targetLoopbackPort,
    String? remotePeerIp,
  }) async {
    await stop();
    _targetLoopbackPort = targetLoopbackPort;

    // 1. On Android, prioritize ultra-low-latency Native Kotlin UDP Relay (2 MB buffer, RT OS priority)
    if (Platform.isAndroid) {
      try {
        final nativePort = await ForegroundServiceHelper.startNativeUdpRelay(
          targetLoopbackPort: targetLoopbackPort,
          remotePeerIp: remotePeerIp,
        );
        if (nativePort != null && nativePort > 0) {
          _usingNativeRelay = true;
          _publicPort = nativePort;
          debugPrint(
            '[LocalUdpRelay] Active using Native Android UDP Relay on 0.0.0.0:$_publicPort <-> 127.0.0.1:$_targetLoopbackPort',
          );
          return _publicPort!;
        }
      } catch (e) {
        debugPrint(
          '[LocalUdpRelay] Native relay start failed, falling back to Dart socket: $e',
        );
      }
    }

    // 2. Production fallback in-process Dart socket loop (for non-Android or fallback)
    _usingNativeRelay = false;
    if (remotePeerIp != null && remotePeerIp.isNotEmpty) {
      try {
        _remotePeerAddress = InternetAddress(remotePeerIp);
      } catch (_) {}
    }

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );
    _socket!.readEventsEnabled = true;
    _publicPort = _socket!.port;

    final loopbackAddr = InternetAddress.loopbackIPv4;

    debugPrint(
      '[LocalUdpRelay] Active using Dart socket on 0.0.0.0:$_publicPort <-> 127.0.0.1:$_targetLoopbackPort (Peer: ${_remotePeerAddress?.address ?? "auto"})',
    );

    _socket!.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          while (true) {
            final dg = _socket?.receive();
            if (dg == null) break;

            final isLoopback =
                dg.address.isLoopback ||
                dg.address.address == '127.0.0.1' ||
                dg.address.address == '::1';

            if (isLoopback) {
              // Outgoing RTCP feedback from local WebRTC loopback -> forward to remote peer
              if (_remotePeerAddress != null && _remotePeerPort != null) {
                _socket?.send(dg.data, _remotePeerAddress!, _remotePeerPort!);
              }
            } else {
              // Incoming RTP video media from remote peer -> forward to local WebRTC loopback
              if (_remotePeerAddress != null &&
                  _remotePeerAddress!.address != dg.address.address) {
                // Ignore unauthorized datagrams from rogue IP
                continue;
              }
              _remotePeerAddress ??= dg.address;
              _remotePeerPort = dg.port;
              if (_targetLoopbackPort != null) {
                _socket?.send(dg.data, loopbackAddr, _targetLoopbackPort!);
              }
            }
          }
        }
      },
      onError: (e) {
        debugPrint('[LocalUdpRelay] Socket error: $e');
      },
    );

    return _publicPort!;
  }

  Future<void> stop() async {
    if (_usingNativeRelay) {
      try {
        await ForegroundServiceHelper.stopNativeUdpRelay();
      } catch (_) {}
      _usingNativeRelay = false;
    }

    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    _publicPort = null;
    _targetLoopbackPort = null;
    _remotePeerAddress = null;
    _remotePeerPort = null;
  }
}
