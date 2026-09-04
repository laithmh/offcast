import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotspot_screen_sharing/core/widgets/exit_confirmation_dialog.dart';

void main() {
  group('ExitConfirmationDialog Widget Tests', () {
    testWidgets('renders title, message, and action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExitConfirmationDialog(
              title: 'Stop Broadcast?',
              message: 'Leaving will disconnect the receiver display.',
              cancelLabel: 'Keep Streaming',
              confirmLabel: 'Stop & Exit',
            ),
          ),
        ),
      );

      expect(find.text('Stop Broadcast?'), findsOneWidget);
      expect(
        find.text('Leaving will disconnect the receiver display.'),
        findsOneWidget,
      );
      expect(find.text('Keep Streaming'), findsOneWidget);
      expect(find.text('Stop & Exit'), findsOneWidget);
    });

    testWidgets('tapping cancel returns false when shown via static helper', (
      tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ExitConfirmationDialog.show(
                    context,
                    title: 'Stop Broadcast?',
                    message: 'Are you sure?',
                    cancelLabel: 'No',
                    confirmLabel: 'Yes',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Stop Broadcast?'), findsOneWidget);

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('tapping confirm returns true when shown via static helper', (
      tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ExitConfirmationDialog.show(
                    context,
                    title: 'Stop Broadcast?',
                    message: 'Are you sure?',
                    cancelLabel: 'No',
                    confirmLabel: 'Yes',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Stop Broadcast?'), findsOneWidget);

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });
}
