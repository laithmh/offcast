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

    testWidgets('renders viewfinder broadcast view with clean telemetry and stop button', (
      tester,
    ) async {
      bool stopped = false;

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
                onDisconnect: () => stopped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('SCREEN MIRRORING ACTIVE'), findsOneWidget);
      expect(find.text('Broadcasting Viewfinder'), findsOneWidget);
      expect(find.text('Target: 192.168.43.1:8080'), findsOneWidget);
      expect(find.text('Stop Broadcast'), findsOneWidget);
      expect(
        find.text(
          'Tip: Dim screen to keep phone cool. Set hotspot to 5 GHz band for 2–5ms ultra-low latency.',
        ),
        findsOneWidget,
      );

      // Camera-specific legacy controls must be absent
      expect(find.text('Switch to Front'), findsNothing);
      expect(find.text('Switch to Rear'), findsNothing);
      expect(find.text('Show Teleprompter on this display'), findsNothing);

      await tester.tap(find.text('Stop Broadcast'));
      await tester.pumpAndSettle();
      expect(stopped, isTrue);
    });
  });
}
