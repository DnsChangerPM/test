import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:advanced_timer/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const AdvancedTimerApp());
    
    // Pump once to build the widget tree
    await tester.pump();
    
    // Verify the app built successfully
    expect(find.text('Advanced Timer'), findsOneWidget);
    
    // Cleanup: pump an empty widget to dispose all previous widgets
    // This clears pending timers from flutter_animate
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
