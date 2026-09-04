import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/models/signaling_message.dart';

class EmbeddedSignalingServer {
  HttpServer? _server;
  WebSocketChannel? _activeClient;
  Timer? _heartbeatTimer;
  DateTime? _lastActivityTime;

  final StreamController<SignalingMessage> _incomingMessagesController =
      StreamController<SignalingMessage>.broadcast();
  final StreamController<bool> _clientConnectionStatusController =
      StreamController<bool>.broadcast();

  Stream<SignalingMessage> get incomingMessages =>
      _incomingMessagesController.stream;
  Stream<bool> get clientConnectionStatus =>
      _clientConnectionStatusController.stream;
  bool get isRunning => _server != null;
  bool get hasConnectedClient => _activeClient != null;

  Future<int> start({int port = WebRTCConstants.signalingPort}) async {
    if (_server != null) {
      return _server!.port;
    }

    final wsHandler = webSocketHandler((
      WebSocketChannel webSocket, [
      dynamic protocol,
    ]) {
      if (_activeClient != null && _activeClient != webSocket) {
        debugPrint(
          '[SignalingServer] Busy: A client is already connected. Rejecting incoming connection.',
        );
        try {
          webSocket.sink.close(4000, 'Server busy with active session');
        } catch (_) {}
        return;
      }

      debugPrint('[SignalingServer] Client connected.');
      _activeClient = webSocket;
      _lastActivityTime = DateTime.now();
      _clientConnectionStatusController.add(true);
      _startHeartbeat();

      webSocket.stream.listen(
        (message) {
          _lastActivityTime = DateTime.now();
          if (message is String) {
            if (message.length > 65536) {
              debugPrint(
                '[SignalingServer] Rejected oversized message (${message.length} bytes)',
              );
              return;
            }
            final sigMsg = SignalingMessage.deserialize(message);
            if (sigMsg != null) {
              if (sigMsg.type == 'ping') {
                sendMessage(SignalingMessage.pong());
              } else if (sigMsg.type != 'pong') {
                _incomingMessagesController.add(sigMsg);
              }
            }
          }
        },
        onDone: () {
          debugPrint('[SignalingServer] Client disconnected.');
          if (_activeClient == webSocket) {
            _activeClient = null;
            _clientConnectionStatusController.add(false);
            _stopHeartbeat();
          }
        },
        onError: (error) {
          debugPrint('[SignalingServer] Client socket error: $error');
          if (_activeClient == webSocket) {
            _activeClient = null;
            _clientConnectionStatusController.add(false);
            _stopHeartbeat();
          }
        },
        cancelOnError: true,
      );
    });

    int currentPort = port;
    int remainingAttempts = 3;
    while (_server == null && remainingAttempts > 0) {
      try {
        _server = await shelf_io.serve(
          wsHandler,
          InternetAddress.anyIPv4,
          currentPort,
          shared: true,
        );
        debugPrint(
          '[SignalingServer] Server running on 0.0.0.0:${_server!.port}',
        );
        return _server!.port;
      } on SocketException catch (e) {
        remainingAttempts--;
        debugPrint(
          '[SignalingServer] Port $currentPort in use or unavailable: $e. Remaining attempts: $remainingAttempts',
        );
        if (remainingAttempts <= 0) {
          rethrow;
        }
        currentPort++;
      } catch (e) {
        debugPrint('[SignalingServer] Failed to start server: $e');
        rethrow;
      }
    }

    return _server!.port;
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_activeClient != null) {
        final lastActivity = _lastActivityTime;
        if (lastActivity != null &&
            DateTime.now().difference(lastActivity) >
                const Duration(seconds: 15)) {
          debugPrint(
            '[SignalingServer] Inactive client timed out (>15s). Closing dead connection.',
          );
          try {
            _activeClient!.sink.close(4001, 'Heartbeat timeout');
          } catch (_) {}
          _activeClient = null;
          _clientConnectionStatusController.add(false);
          _stopHeartbeat();
          return;
        }
        sendMessage(SignalingMessage.ping());
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void sendMessage(SignalingMessage message) {
    if (_activeClient != null) {
      try {
        _activeClient!.sink.add(message.serialize());
      } catch (e) {
        debugPrint('[SignalingServer] Error sending message to client: $e');
      }
    } else {
      debugPrint('[SignalingServer] Cannot send message, no active client.');
    }
  }

  Future<void> stop() async {
    debugPrint('[SignalingServer] Stopping server...');
    _stopHeartbeat();
    try {
      if (_activeClient != null) {
        await _activeClient!.sink.close();
        _activeClient = null;
      }
      if (_server != null) {
        await _server!.close(force: true);
        _server = null;
      }
    } catch (e) {
      debugPrint('[SignalingServer] Error during stop: $e');
    }
  }

  Future<void> dispose() async {
    await stop();
    await _incomingMessagesController.close();
    await _clientConnectionStatusController.close();
  }
}
