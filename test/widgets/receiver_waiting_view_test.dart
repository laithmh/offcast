import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotspot_screen_sharing/features/receiver/bloc/receiver_state.dart';
import 'package:hotspot_screen_sharing/features/receiver/presentation/widgets/receiver_waiting_view.dart';

void main() {
  group('ReceiverWaitingView Widget Tests', () {
    late AnimationController pulseController;

    setUp(() {
      pulseController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
    });

    tearDown(() {
      pulseController.dispose();
    });

    testWidgets('renders offline banner and prompt when localIp is null', (
      tester,
    ) async {
      const state = ReceiverState(localIp: null, port: 8080);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiverWaitingView(
              state: state,
              pulseAnimation: pulseController,
            ),
          ),
        ),
      );

      expect(find.text('Wi-Fi / Hotspot Offline'), findsOneWidget);
      expect(find.text('Waiting for Wi-Fi / Hotspot...'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsWidgets);
      expect(find.byIcon(Icons.copy_rounded), findsNothing);
    });

    testWidgets(
      'renders WebSocket URL and copy button when localIp is present',
      (tester) async {
        const state = ReceiverState(localIp: '192.168.43.1', port: 8080);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReceiverWaitingView(
                state: state,
                pulseAnimation: pulseController,
              ),
            ),
          ),
        );

        expect(find.text('Wi-Fi / Hotspot Offline'), findsNothing);
        expect(find.text('Waiting for Incoming Stream...'), findsOneWidget);
        expect(find.text('ws://192.168.43.1:8080'), findsOneWidget);
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

        // Tap the copy button and verify snackbar appears
        await tester.tap(find.byIcon(Icons.copy_rounded));
        await tester.pump(); // Start snackbar animation

        expect(find.text('Address copied to clipboard'), findsOneWidget);
      },
    );

    testWidgets('renders negotiating status when client is connected', (
      tester,
    ) async {
      const state = ReceiverState(
        localIp: '192.168.43.1',
        port: 8080,
        isClientConnected: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiverWaitingView(
              state: state,
              pulseAnimation: pulseController,
            ),
          ),
        ),
      );

      expect(find.text('Sender Connected. Negotiating...'), findsOneWidget);
    });
  });
}
