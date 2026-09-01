import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A lightweight, in-process UDP relay that bridges WebRTC loopback sockets
/// (127.0.0.1:port) with physical Wi-Fi Hotspot / LAN interfaces (0.0.0.0:port).
///
/// This solves the Android SoftAP issue where WebRTC's C++ NetworkMonitor fails to
/// enumerate the Hotspot AP interface and binds sockets only to loopback (127.0.0.1).
class LocalUdpRelay {
  RawDatagramSocket? _socket;
  int? _publicPort;
  int? _targetLoopbackPort;
  InternetAddress? _remotePeerAddress;
  int? _remotePeerPort;

  int? get publicPort => _publicPort;

  /// Starts the relay listening on 0.0.0.0 and bridging to the target loopback port
  Future<int> start({required int targetLoopbackPort}) async {
    await stop();
    _targetLoopbackPort = targetLoopbackPort;

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );
    _socket!.readEventsEnabled = true;
    _publicPort = _socket!.port;

    debugPrint(
      '[LocalUdpRelay] Active on 0.0.0.0:$_publicPort <-> 127.0.0.1:$_targetLoopbackPort',
    );

    _socket!.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          while (true) {
            final dg = _socket?.receive();
            if (dg == null) break;

            if (dg.address == InternetAddress.loopbackIPv4) {
              // Outgoing packet from local WebRTC socket -> forward to remote peer
              if (_remotePeerAddress != null && _remotePeerPort != null) {
                _socket?.send(dg.data, _remotePeerAddress!, _remotePeerPort!);
              }
            } else {
              // Incoming packet from remote peer -> forward to local WebRTC loopback socket
              _remotePeerAddress = dg.address;
              _remotePeerPort = dg.port;
              if (_targetLoopbackPort != null) {
                _socket?.send(
                  dg.data,
                  InternetAddress.loopbackIPv4,
                  _targetLoopbackPort!,
                );
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
