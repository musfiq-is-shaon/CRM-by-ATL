import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm/presentation/widgets/loading_widget.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  testWidgets('ShimmerCard renders fixed height', (tester) async {
    await tester.pumpWidget(wrap(const ShimmerCard(height: 76)));
    await tester.pump();
    expect(find.byType(ShimmerCard), findsOneWidget);
    final box = tester.renderObject<RenderBox>(find.byType(ShimmerCard));
    expect(box.size.height, 76);
  });

  testWidgets('ListSkeletonLoader shows requested item count', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          height: 600,
          child: ListSkeletonLoader(itemCount: 4, shrinkWrap: true),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ShimmerCard), findsNWidgets(4));
  });

  testWidgets('DashboardSkeleton builds without layout overflow', (tester) async {
    await tester.pumpWidget(wrap(const DashboardSkeleton()));
    await tester.pump();
    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.byType(AttendanceCardSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LunchMyLunchSkeleton matches section order', (tester) async {
    await tester.pumpWidget(wrap(const LunchMyLunchSkeleton()));
    await tester.pump();
    expect(find.byType(ShimmerCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsFormSkeleton builds without overflow', (tester) async {
    await tester.pumpWidget(wrap(const SettingsFormSkeleton()));
    await tester.pump();
    expect(find.byType(SettingsFormSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DetailSkeleton builds without layout overflow', (tester) async {
    await tester.pumpWidget(wrap(const DetailSkeleton()));
    await tester.pump();
    expect(find.byType(DetailSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AttendanceCardSkeleton uses fixed height', (tester) async {
    await tester.pumpWidget(wrap(const AttendanceCardSkeleton()));
    await tester.pump();
    final box =
        tester.renderObject<RenderBox>(find.byType(AttendanceCardSkeleton));
    expect(box.size.height, 228);
  });

  testWidgets('LoadingWidget shows optional message', (tester) async {
    await tester.pumpWidget(wrap(const LoadingWidget(message: 'Please wait')));
    await tester.pump();
    expect(find.text('Please wait'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('InlineRefreshIndicator shows updating copy', (tester) async {
    await tester.pumpWidget(wrap(const InlineRefreshIndicator()));
    await tester.pump();
    expect(find.text('Updating…'), findsOneWidget);
  });
}
