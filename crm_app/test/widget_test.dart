import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:CRM/app.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CRMApp()),
    );
    await tester.pump();
    expect(find.byType(CRMApp), findsOneWidget);
  });
}
