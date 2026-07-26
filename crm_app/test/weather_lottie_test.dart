import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm/data/models/weather_model.dart';
import 'package:crm/presentation/widgets/weather_mood_animation.dart';

void main() {
  testWidgets('WeatherMoodAnimation renders and animates', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeatherMoodAnimation(
            kind: DashboardWeatherKind.stormy,
            size: 80,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(WeatherMoodAnimation), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  test('WeatherAPI condition codes map correctly', () {
    expect(DashboardWeather.labelFromWeatherApiCode(1000), 'Clear');
    expect(
      DashboardWeather.kindFromWeatherApiCode(1276),
      DashboardWeatherKind.stormy,
    );
  });
}
