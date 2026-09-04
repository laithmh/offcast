import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotspot_screen_sharing/core/constants/webrtc_constants.dart';
import 'package:hotspot_screen_sharing/features/sender/bloc/sender_bloc.dart';
import 'package:hotspot_screen_sharing/features/sender/bloc/sender_state.dart';
import 'package:hotspot_screen_sharing/features/sender/data/sender_webrtc_service.dart';
import 'package:hotspot_screen_sharing/features/sender/presentation/widgets/stream_source_card.dart';

void main() {
  group('StreamSourceCard Widget Tests', () {
    late SenderWebRTCService webrtcService;
    late SenderBloc senderBloc;

    setUp(() {
      webrtcService = SenderWebRTCService();
      senderBloc = SenderBloc(webrtcService: webrtcService);
    });

    tearDown(() async {
      await senderBloc.close();
    });

    testWidgets('renders both Studio Camera and Screen Mirroring options', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<SenderBloc>.value(
              value: senderBloc,
              child: const StreamSourceCard(
                state: SenderState(streamSource: StreamSourceType.studioCamera),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Stream Source'), findsOneWidget);
      expect(find.text('Direct Studio Camera'), findsOneWidget);
      expect(find.text('Screen Mirroring'), findsOneWidget);
      expect(find.text('1080p 60 FPS + Prompter'), findsOneWidget);
      expect(find.text('Mirror Phone Screen'), findsOneWidget);
    });

    testWidgets('tapping Screen Mirroring updates bloc state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<SenderBloc>.value(
              value: senderBloc,
              child: BlocBuilder<SenderBloc, SenderState>(
                builder: (context, state) => StreamSourceCard(state: state),
              ),
            ),
          ),
        ),
      );

      // Default streamSource is studioCamera
      expect(
        senderBloc.state.streamSource,
        equals(StreamSourceType.studioCamera),
      );

      await tester.tap(find.text('Screen Mirroring'));
      await tester.pumpAndSettle();

      expect(senderBloc.state.streamSource, equals(StreamSourceType.screen));
    });
  });
}
