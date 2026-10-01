import 'package:flutter_test/flutter_test.dart';
import 'package:advanced_timer/main.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const AdvancedTimerApp());
    expect(find.text('Advanced Timer'), findsOneWidget);
  });
}
