import 'package:flutter_test/flutter_test.dart';
import 'package:hotspot_screen_sharing/main.dart';

void main() {
  testWidgets('App launches and renders Mode Selector options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HotspotScreenSharingApp());
    await tester.pumpAndSettle();

    expect(find.text('OffCast'), findsOneWidget);
    expect(find.text('Receiver Mode'), findsOneWidget);
    expect(find.text('Sender Mode'), findsOneWidget);
    expect(find.text('Start Receiver'), findsOneWidget);
    expect(find.text('Start Sender'), findsOneWidget);
  });
}
