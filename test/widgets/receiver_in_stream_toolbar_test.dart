import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hotspot_screen_sharing/core/constants/webrtc_constants.dart';
import 'package:hotspot_screen_sharing/features/receiver/bloc/receiver_bloc.dart';
import 'package:hotspot_screen_sharing/features/receiver/bloc/receiver_event.dart';
import 'package:hotspot_screen_sharing/features/receiver/bloc/receiver_state.dart';
import 'package:hotspot_screen_sharing/features/receiver/presentation/widgets/receiver_in_stream_toolbar.dart';

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

void main() {
  group('ReceiverInStreamToolbar Widget Tests', () {
    late FakeReceiverBloc fakeReceiverBloc;

    setUp(() {
      fakeReceiverBloc = FakeReceiverBloc();
    });

    tearDown(() async {
      await fakeReceiverBloc.close();
    });

    testWidgets(
      'in viewfinder stream mode: renders display controls and teleprompter tools',
      (tester) async {
        const state = ReceiverState(
          isStreaming: true,
          streamSource: StreamSourceType.screen,
          isPrompterOverlayVisible: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BlocProvider<ReceiverBloc>.value(
                value: fakeReceiverBloc,
                child: ReceiverInStreamToolbar(
                  state: state,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  isMirrored: false,
                  onToggleFit: () {},
                  onCycleTurns: () {},
                  onToggleMirror: () {},
                ),
              ),
            ),
          ),
        );

        // Essential display controls should be present
        expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
        expect(find.byIcon(Icons.rotate_right_rounded), findsOneWidget);
        expect(find.byIcon(Icons.flip_rounded), findsOneWidget);
        expect(find.byIcon(Icons.aspect_ratio_rounded), findsOneWidget);

        // Prompter controls are available
        expect(find.byIcon(Icons.subtitles_off_rounded), findsOneWidget);
        expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);

        // Camera switch button is absent
        expect(find.byIcon(Icons.cameraswitch_rounded), findsNothing);
      },
    );

    testWidgets(
      'when prompter overlay is visible: shows active prompter icon',
      (tester) async {
        const state = ReceiverState(
          isStreaming: true,
          streamSource: StreamSourceType.screen,
          isPrompterOverlayVisible: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BlocProvider<ReceiverBloc>.value(
                value: fakeReceiverBloc,
                child: ReceiverInStreamToolbar(
                  state: state,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  isMirrored: false,
                  onToggleFit: () {},
                  onCycleTurns: () {},
                  onToggleMirror: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.subtitles_rounded), findsOneWidget);
        expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
      },
    );
  });
}
