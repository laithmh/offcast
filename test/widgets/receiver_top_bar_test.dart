import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotspot_screen_sharing/core/constants/webrtc_constants.dart';
import 'package:hotspot_screen_sharing/features/receiver/bloc/receiver_bloc.dart';
import 'package:hotspot_screen_sharing/features/receiver/bloc/receiver_event.dart';
import 'package:hotspot_screen_sharing/features/receiver/bloc/receiver_state.dart';
import 'package:hotspot_screen_sharing/features/receiver/data/receiver_webrtc_service.dart';
import 'package:hotspot_screen_sharing/features/receiver/presentation/widgets/receiver_top_bar.dart';

class FakeReceiverBloc extends Bloc<ReceiverEvent, ReceiverState>
    implements ReceiverBloc {
  FakeReceiverBloc([super.initialState = const ReceiverState()]);

  final List<ReceiverEvent> dispatchedEvents = [];

  @override
  void add(ReceiverEvent event) {
    dispatchedEvents.add(event);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReceiverWebRTCService implements ReceiverWebRTCService {
  final StreamController<StreamPerformanceStats> _statsController =
      StreamController<StreamPerformanceStats>.broadcast();

  @override
  Stream<StreamPerformanceStats> get statsStream => _statsController.stream;

  void emitStats(StreamPerformanceStats stats) {
    _statsController.add(stats);
  }

  @override
  Future<void> dispose() async {
    await _statsController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ReceiverTopBar Widget Tests', () {
    late FakeReceiverWebRTCService fakeWebRTCService;
    late FakeReceiverBloc fakeReceiverBloc;

    setUp(() {
      fakeWebRTCService = FakeReceiverWebRTCService();
      fakeReceiverBloc = FakeReceiverBloc();
    });

    tearDown(() async {
      await fakeReceiverBloc.close();
      fakeWebRTCService.dispose();
    });

    testWidgets(
      'renders top bar in idle state with IP address and Restart button',
      (tester) async {
        const state = ReceiverState(
          localIp: '192.168.43.1',
          port: 8080,
          isStreaming: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<ReceiverBloc>.value(value: fakeReceiverBloc),
                  RepositoryProvider<ReceiverWebRTCService>.value(
                    value: fakeWebRTCService,
                  ),
                ],
                child: const ReceiverTopBar(state: state),
              ),
            ),
          ),
        );

        expect(find.text('Display Viewfinder'), findsOneWidget);
        expect(find.text('ws://192.168.43.1:8080'), findsOneWidget);
        expect(find.text('Restart'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      },
    );

    testWidgets('renders warning text when localIp is null', (tester) async {
      const state = ReceiverState(
        localIp: null,
        port: 8080,
        isStreaming: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<ReceiverBloc>.value(value: fakeReceiverBloc),
                RepositoryProvider<ReceiverWebRTCService>.value(
                  value: fakeWebRTCService,
                ),
              ],
              child: const ReceiverTopBar(state: state),
            ),
          ),
        ),
      );

      expect(find.text('No Hotspot / Wi-Fi Active'), findsOneWidget);
    });

    testWidgets('renders Reset button and telemetry when streaming', (
      tester,
    ) async {
      const state = ReceiverState(
        localIp: '192.168.43.1',
        port: 8080,
        isStreaming: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<ReceiverBloc>.value(value: fakeReceiverBloc),
                RepositoryProvider<ReceiverWebRTCService>.value(
                  value: fakeWebRTCService,
                ),
              ],
              child: const ReceiverTopBar(state: state),
            ),
          ),
        ),
      );

      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Live Stream Active'), findsOneWidget);

      // Emit stats with thermal data
      fakeWebRTCService.emitStats(
        const StreamPerformanceStats(
          fps: 60,
          bitrateMbps: 8.5,
          latencyMs: 16,
          senderTemperatureC: 41.2,
          receiverTemperatureC: 38.0,
          senderDeviceName: 'Pixel',
          receiverDeviceName: 'Tablet',
        ),
      );
      await tester.pump();

      expect(find.text('60.0 FPS • 8.5 Mbps • 16ms'), findsOneWidget);
      expect(find.text('Pixel 41.2°C'), findsOneWidget);
      expect(find.text('Tablet 38.0°C'), findsOneWidget);
    });

    testWidgets(
      'tapping Restart dispatches ReceiverStartServerRequested event',
      (tester) async {
        const state = ReceiverState(
          localIp: '192.168.43.1',
          port: 8080,
          isStreaming: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<ReceiverBloc>.value(value: fakeReceiverBloc),
                  RepositoryProvider<ReceiverWebRTCService>.value(
                    value: fakeWebRTCService,
                  ),
                ],
                child: const ReceiverTopBar(state: state),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Restart'));
        await tester.pump();

        expect(fakeReceiverBloc.dispatchedEvents, [
          isA<ReceiverStartServerRequested>(),
        ]);
      },
    );
  });
}
