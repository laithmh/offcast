import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
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
  String? _requiredPin;
  bool _lastUpgradeAuthenticated = false;

  final Map<String, List<DateTime>> _failedAttemptsByIp = {};

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
  String? get requiredPin => _requiredPin;

  void updateRequiredPin(String? pin) {
    _requiredPin = pin;
    _failedAttemptsByIp.clear();
    debugPrint(
      '[SignalingServer] Required pairing PIN updated: $_requiredPin (lockouts reset)',
    );
  }

  bool _isIpLockedOut(String ip) {
    final attempts = _failedAttemptsByIp[ip];
    if (attempts == null) return false;
    final now = DateTime.now();
    attempts.removeWhere((t) => now.difference(t) > const Duration(seconds: 30));
    return attempts.length >= 5;
  }

  void _recordFailedAttempt(String ip) {
    final now = DateTime.now();
    final list = _failedAttemptsByIp.putIfAbsent(ip, () => []);
    list.removeWhere((t) => now.difference(t) > const Duration(seconds: 30));
    list.add(now);
  }

  void _resetFailedAttempts(String ip) {
    _failedAttemptsByIp.remove(ip);
  }

  Future<int> start({
    int port = WebRTCConstants.signalingPort,
    String? requiredPin,
  }) async {
    if (_server != null) {
      _requiredPin = requiredPin;
      return _server!.port;
    }

    _requiredPin = requiredPin;

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

      bool clientIsAuthenticated = _lastUpgradeAuthenticated ||
          (_requiredPin == null || _requiredPin!.isEmpty);
      Timer? authTimer;

      if (!clientIsAuthenticated) {
        debugPrint(
          '[SignalingServer] Client connected without URL PIN. Awaiting in-band auth (3s grace)...',
        );
        authTimer = Timer(const Duration(seconds: 3), () {
          if (!clientIsAuthenticated) {
            debugPrint(
              '[SignalingServer] Auth timeout: Client failed to authenticate in 3s. Disconnecting.',
            );
            try {
              webSocket.sink.close(4401, 'Unauthorized: Auth timeout');
            } catch (_) {}
          }
        });
      }

      debugPrint(
        '[SignalingServer] Client connected. (Authenticated: $clientIsAuthenticated)',
      );
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
              if (!clientIsAuthenticated) {
                if (sigMsg.type == 'auth') {
                  final pin = sigMsg.payload?['pin'] as String?;
                  if (pin == _requiredPin) {
                    clientIsAuthenticated = true;
                    authTimer?.cancel();
                    authTimer = null;
                    debugPrint(
                      '[SignalingServer] In-band auth verified for client.',
                    );
                    sendMessage(SignalingMessage.authResponse(success: true));
                    return;
                  } else {
                    debugPrint(
                      '[SignalingServer] In-band auth failed: invalid PIN "$pin"',
                    );
                    sendMessage(
                      SignalingMessage.authResponse(
                        success: false,
                        reason: 'Invalid pairing PIN',
                      ),
                    );
                    try {
                      webSocket.sink.close(4401, 'Unauthorized: Invalid PIN');
                    } catch (_) {}
                    return;
                  }
                } else {
                  debugPrint(
                    '[SignalingServer] Dropped unauthenticated message: ${sigMsg.type}',
                  );
                  return;
                }
              }

              if (sigMsg.type == 'ping') {
                sendMessage(SignalingMessage.pong());
              } else if (sigMsg.type != 'pong') {
                _incomingMessagesController.add(sigMsg);
              }
            }
          }
        },
        onDone: () {
          authTimer?.cancel();
          authTimer = null;
          debugPrint('[SignalingServer] Client disconnected.');
          if (_activeClient == webSocket) {
            _activeClient = null;
            _clientConnectionStatusController.add(false);
            _stopHeartbeat();
          }
        },
        onError: (error) {
          authTimer?.cancel();
          authTimer = null;
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

    // Custom Shelf pipeline verifying PIN during HTTP upgrade before creating WebSocket
    FutureOr<Response> appHandler(Request request) {
      final info =
          request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final clientIp = info?.remoteAddress.address ?? 'unknown';

      if (_isIpLockedOut(clientIp)) {
        debugPrint(
          '[SignalingServer] 429 Locked out: IP $clientIp exceeded failed PIN attempts.',
        );
        return Response(
          429,
          body: 'Too many failed PIN attempts. Please wait 30 seconds.',
        );
      }

      _lastUpgradeAuthenticated = false;

      if (_requiredPin != null && _requiredPin!.isNotEmpty) {
        final providedPin = request.url.queryParameters['pin'];
        if (providedPin != null) {
          if (providedPin != _requiredPin) {
            _recordFailedAttempt(clientIp);
            debugPrint(
              '[SignalingServer] 401 Unauthorized: Invalid PIN "$providedPin" from $clientIp',
            );
            return Response(
              401,
              body: 'Unauthorized: Invalid pairing PIN',
            );
          } else {
            _resetFailedAttempts(clientIp);
            _lastUpgradeAuthenticated = true;
          }
        }
      }

      return wsHandler(request);
    }

    int currentPort = port;
    int remainingAttempts = 3;
    while (_server == null && remainingAttempts > 0) {
      try {
        _server = await shelf_io.serve(
          appHandler,
          InternetAddress.anyIPv4,
          currentPort,
          shared: true,
        );
        debugPrint(
          '[SignalingServer] Server running on 0.0.0.0:${_server!.port} (PIN required: ${_requiredPin != null})',
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
