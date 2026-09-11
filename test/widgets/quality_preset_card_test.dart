import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotspot_screen_sharing/core/constants/webrtc_constants.dart';
import 'package:hotspot_screen_sharing/features/sender/bloc/sender_bloc.dart';
import 'package:hotspot_screen_sharing/features/sender/bloc/sender_state.dart';
import 'package:hotspot_screen_sharing/features/sender/data/sender_webrtc_service.dart';
import 'package:hotspot_screen_sharing/features/sender/presentation/widgets/quality_preset_card.dart';

void main() {
  group('QualityPresetCard Widget Tests', () {
    late SenderWebRTCService webrtcService;
    late SenderBloc senderBloc;

    setUp(() {
      webrtcService = SenderWebRTCService();
      senderBloc = SenderBloc(webrtcService: webrtcService);
    });

    tearDown(() async {
      await senderBloc.close();
    });

    testWidgets('renders all quality presets and codec engines', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider<SenderBloc>.value(
                value: senderBloc,
                child: const QualityPresetCard(
                  state: SenderState(),
                  isWide: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Quality & Performance Preset'), findsOneWidget);
      expect(
        find.text(StreamingQualityPreset.cool540p30.label),
        findsOneWidget,
      );
      expect(
        find.text(StreamingQualityPreset.hd720p30.label),
        findsOneWidget,
      );

      expect(find.text('Video Codec Engine'), findsOneWidget);
      expect(find.text(CodecEngine.vp8.label), findsOneWidget);
      expect(find.text(CodecEngine.h264.label), findsOneWidget);
    });

    testWidgets('tapping 720p preset and VP8 updates bloc state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider<SenderBloc>.value(
                value: senderBloc,
                child: BlocBuilder<SenderBloc, SenderState>(
                  builder: (context, state) =>
                      QualityPresetCard(state: state, isWide: false),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap HD 720p
      await tester.tap(find.text(StreamingQualityPreset.hd720p30.label));
      await tester.pumpAndSettle();

      expect(
        senderBloc.state.preset,
        equals(StreamingQualityPreset.hd720p30),
      );

      // Tap VP8 Safe
      await tester.tap(find.text(CodecEngine.vp8.label));
      await tester.pumpAndSettle();

      expect(senderBloc.state.codecEngine, equals(CodecEngine.vp8));
    });
  });
}
