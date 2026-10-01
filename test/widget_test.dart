import 'package:flutter_test/flutter_test.dart';
import 'package:advanced_timer/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AdvancedTimerApp());

    // Pump once to build the widget tree
    await tester.pump();

    // Verify the app built successfully
    expect(find.text('Advanced Timer'), findsOneWidget);

    // Don't use pumpAndSettle - it will wait forever for repeating animations
    // The test will complete successfully even with pending animation timers
  });
}
