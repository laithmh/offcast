import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotspot_screen_sharing/core/constants/webrtc_constants.dart';
import 'package:hotspot_screen_sharing/features/sender/bloc/sender_bloc.dart';
import 'package:hotspot_screen_sharing/features/sender/bloc/sender_state.dart';
import 'package:hotspot_screen_sharing/features/sender/data/sender_webrtc_service.dart';
import 'package:hotspot_screen_sharing/features/sender/presentation/widgets/connected_sender_view.dart';

void main() {
  group('ConnectedSenderView Widget Tests', () {
    late SenderWebRTCService webrtcService;
    late SenderBloc senderBloc;

    setUp(() {
      webrtcService = SenderWebRTCService();
      senderBloc = SenderBloc(webrtcService: webrtcService);
    });

    tearDown(() async {
      await senderBloc.close();
    });

    testWidgets(
      'renders camera transmitter view with full spec badges and controls',
      (tester) async {
        bool disconnected = false;

        const cameraState = SenderState(
          status: SenderConnectionState.streaming,
          streamSource: StreamSourceType.studioCamera,
          cameraFacing: CameraFacingMode.environment,
          targetHost: '192.168.43.1',
          targetPort: 8080,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RepositoryProvider<SenderWebRTCService>.value(
              value: webrtcService,
              child: BlocProvider<SenderBloc>.value(
                value: senderBloc,
                child: ConnectedSenderView(
                  state: cameraState,
                  onDisconnect: () => disconnected = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('CAMERA TRANSMITTER ACTIVE'), findsOneWidget);
        expect(find.text('Direct Studio Camera Feed'), findsOneWidget);
        expect(find.text('Target: 192.168.43.1:8080'), findsOneWidget);
        expect(find.text('Rear Sensor'), findsOneWidget);
        expect(find.text('Switch to Front'), findsOneWidget);
        expect(find.text('Disconnect'), findsOneWidget);
        expect(find.text('Show Teleprompter on this display'), findsOneWidget);

        await tester.tap(find.text('Disconnect'));
        await tester.pumpAndSettle();
        expect(disconnected, isTrue);
      },
    );

    testWidgets('renders front camera state correctly', (tester) async {
      const frontState = SenderState(
        status: SenderConnectionState.streaming,
        streamSource: StreamSourceType.studioCamera,
        cameraFacing: CameraFacingMode.user,
        targetHost: '192.168.43.1',
        targetPort: 8080,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<SenderWebRTCService>.value(
            value: webrtcService,
            child: BlocProvider<SenderBloc>.value(
              value: senderBloc,
              child: ConnectedSenderView(
                state: frontState,
                onDisconnect: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Front Sensor'), findsOneWidget);
      expect(find.text('Switch to Rear'), findsOneWidget);
    });

    testWidgets('renders screen mirror view cleanly without camera controls', (
      tester,
    ) async {
      const screenState = SenderState(
        status: SenderConnectionState.streaming,
        streamSource: StreamSourceType.screen,
        targetHost: '192.168.43.1',
        targetPort: 8080,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<SenderWebRTCService>.value(
            value: webrtcService,
            child: BlocProvider<SenderBloc>.value(
              value: senderBloc,
              child: ConnectedSenderView(
                state: screenState,
                onDisconnect: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('SCREEN MIRRORING ACTIVE'), findsOneWidget);
      expect(find.text('Connected to Viewer Monitor'), findsOneWidget);
      expect(find.text('Switch to Front'), findsNothing);
      expect(find.text('Switch to Rear'), findsNothing);
      expect(find.text('Show Teleprompter on this display'), findsNothing);
      expect(find.text('Disconnect'), findsOneWidget);
    });
  });
}
