import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import '../../../core/models/signaling_message.dart';

/// Clean WebSocket signaling client for the Sender role.
/// Manages WebSocket lifecycle, message serialization, and heartbeat watchdog.
class SenderSignalingClient {
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _livenessWatchdog;
  DateTime _lastActivity = DateTime.now();

  final _messageController = StreamController<SignalingMessage>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<SignalingMessage> get onMessage => _messageController.stream;
  Stream<void> get onDisconnected => _disconnectController.stream;
  Stream<String> get onError => _errorController.stream;

  bool get isConnected => _channel != null;

  /// Connects to the Receiver signaling server with optional pre-shared pairing PIN
  Future<void> connect(
    String host,
    int port, {
    String? pin,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await disconnect();

    final wsUri = Uri(
      scheme: 'ws',
      host: host,
      port: port,
      path: '/ws',
      queryParameters: (pin != null && pin.isNotEmpty) ? {'pin': pin} : null,
    );
    debugPrint('[SignalingClient] Connecting to $wsUri');

    try {
      final ws = await WebSocket.connect(wsUri.toString()).timeout(timeout);
      _channel = IOWebSocketChannel(ws);
      _lastActivity = DateTime.now();
      _startWatchdog();

      // Send secondary in-band auth message if PIN is provided
      if (pin != null && pin.isNotEmpty) {
        send(SignalingMessage.auth(pin: pin));
      }

      _subscription = _channel!.stream.listen(
        (dynamic rawMessage) {
          _lastActivity = DateTime.now();
          try {
            final json =
                jsonDecode(rawMessage as String) as Map<String, dynamic>;
            final message = SignalingMessage.fromJson(json);

            if (message.type == 'auth_response') {
              final success = message.payload?['success'] as bool? ?? false;
              if (!success) {
                final reason =
                    message.payload?['reason'] as String? ?? 'Invalid pairing PIN';
                _errorController.add('Pairing failed: $reason');
                disconnect();
                return;
              } else {
                debugPrint('[SignalingClient] In-band pairing auth confirmed by server.');
              }
            }

            _messageController.add(message);
          } catch (e, stack) {
            debugPrint('[SignalingClient] Error parsing message: $e\n$stack');
          }
        },
        onError: (error) {
          debugPrint('[SignalingClient] Channel error: $error');
          _errorController.add('Signaling error: $error');
        },
        onDone: () {
          debugPrint('[SignalingClient] WebSocket closed');
          _disconnectController.add(null);
        },
        cancelOnError: true,
      );
    } on SocketException catch (e) {
      debugPrint('[SignalingClient] SocketException during connect: $e');
      rethrow;
    } on HttpException catch (e) {
      debugPrint('[SignalingClient] HttpException during connect: $e');
      if (e.message.contains('401') || e.message.contains('403')) {
        throw Exception(
          'Unauthorized: Incorrect pairing PIN. Please verify the 4-digit PIN on the receiver screen.',
        );
      } else if (e.message.contains('429')) {
        throw Exception(
          'Too many failed PIN attempts. Locked out for 30 seconds.',
        );
      }
      rethrow;
    } catch (e) {
      final str = e.toString();
      if (str.contains('401') || str.contains('403')) {
        throw Exception(
          'Unauthorized: Incorrect pairing PIN. Please verify the 4-digit PIN on the receiver screen.',
        );
      } else if (str.contains('429')) {
        throw Exception(
          'Too many failed PIN attempts. Locked out for 30 seconds.',
        );
      }
      rethrow;
    }
  }

  /// Sends a signaling message to the receiver
  void send(SignalingMessage message) {
    if (_channel != null) {
      try {
        final encoded = jsonEncode(message.toJson());
        _channel!.sink.add(encoded);
      } catch (e) {
        debugPrint('[SignalingClient] Error sending message: $e');
      }
    }
  }

  void _startWatchdog() {
    _livenessWatchdog?.cancel();
    _livenessWatchdog = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_channel == null) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_lastActivity);
      if (elapsed > const Duration(seconds: 9)) {
        debugPrint('[SignalingClient] Liveness watchdog: No heartbeat in 9s.');
        _errorController.add('Receiver display timed out (heartbeat lost).');
        _disconnectController.add(null);
        timer.cancel();
        return;
      }
      send(SignalingMessage.ping());
    });
  }

  /// Closes signaling connection and watchdog timers
  Future<void> disconnect() async {
    _livenessWatchdog?.cancel();
    _livenessWatchdog = null;

    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _disconnectController.close();
    _errorController.close();
  }
}
