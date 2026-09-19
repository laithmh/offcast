import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hotspot_screen_sharing/core/models/signaling_message.dart';
import 'package:hotspot_screen_sharing/features/receiver/data/embedded_signaling_server.dart';

void main() {
  group('EmbeddedSignalingServer Tests', () {
    late EmbeddedSignalingServer server;

    setUp(() {
      server = EmbeddedSignalingServer();
    });

    tearDown(() async {
      await server.dispose();
    });

    test('starts on specified port or next available port', () async {
      final testPort = 18080;
      final port = await server.start(port: testPort);
      expect(port, equals(testPort));
      expect(server.isRunning, isTrue);
      expect(server.hasConnectedClient, isFalse);
    });

    test(
      'automatically falls back to next port when first port is in use',
      () async {
        final busySocket = await ServerSocket.bind(
          InternetAddress.anyIPv4,
          18085,
        );

        try {
          final assignedPort = await server.start(port: 18085);
          expect(assignedPort, equals(18086));
          expect(server.isRunning, isTrue);
        } finally {
          await busySocket.close();
        }
      },
    );

    test('tracks client connection and handles messaging', () async {
      final port = await server.start(port: 18090);

      final clientWs = await WebSocket.connect('ws://127.0.0.1:$port');
      // Wait for server to register connection
      await Future.delayed(const Duration(milliseconds: 100));

      expect(server.hasConnectedClient, isTrue);

      final incomingFuture = server.incomingMessages.first;
      clientWs.add(SignalingMessage.bye().serialize());

      final received = await incomingFuture.timeout(const Duration(seconds: 2));
      expect(received.type, equals('bye'));

      await clientWs.close();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(server.hasConnectedClient, isFalse);
    });

    test('accepts connection with valid PIN in query parameter', () async {
      final port = await server.start(port: 18092, requiredPin: '4829');

      final clientWs = await WebSocket.connect(
        'ws://127.0.0.1:$port/ws?pin=4829',
      );
      await Future.delayed(const Duration(milliseconds: 100));

      expect(server.hasConnectedClient, isTrue);

      final incomingFuture = server.incomingMessages.first;
      clientWs.add(SignalingMessage.bye().serialize());

      final received = await incomingFuture.timeout(const Duration(seconds: 2));
      expect(received.type, equals('bye'));

      await clientWs.close();
    });

    test(
      'rejects connection with invalid PIN in query parameter with HTTP 401',
      () async {
        final port = await server.start(port: 18094, requiredPin: '4829');

        expect(
          () async =>
              await WebSocket.connect('ws://127.0.0.1:$port/ws?pin=9999'),
          throwsA(anything),
        );
        await Future.delayed(const Duration(milliseconds: 100));
        expect(server.hasConnectedClient, isFalse);
      },
    );

    test(
      'verifies in-band auth handshake when connecting without URL PIN',
      () async {
        final port = await server.start(port: 18096, requiredPin: '5566');

        final clientWs = await WebSocket.connect('ws://127.0.0.1:$port');
        await Future.delayed(const Duration(milliseconds: 50));

        // Send in-band auth message
        clientWs.add(SignalingMessage.auth(pin: '5566').serialize());

        // Client should receive auth_response with success: true
        final responseStr = await clientWs.first.timeout(
          const Duration(seconds: 2),
        );
        final responseMsg = SignalingMessage.deserialize(responseStr as String);
        expect(responseMsg?.type, equals('auth_response'));
        expect(responseMsg?.payload?['success'], isTrue);

        // Now server should accept normal messages
        final incomingFuture = server.incomingMessages.first;
        clientWs.add(SignalingMessage.bye().serialize());

        final received = await incomingFuture.timeout(
          const Duration(seconds: 2),
        );
        expect(received.type, equals('bye'));

        await clientWs.close();
      },
    );
  });
}
