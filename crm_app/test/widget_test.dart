import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crm/app.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CRMApp()),
    );
    await tester.pump();
    // Clear launch-hold delay + attendance reminder debounce timers.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CRMApp), findsOneWidget);
  });
}
