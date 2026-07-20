import 'package:flutter/material.dart';

import '../../data/models/weather_model.dart';

class WeatherPalette {
  const WeatherPalette({
    required this.gradient,
    required this.text,
    required this.shadow,
  });

  final List<Color> gradient;
  final Color text;
  final Color shadow;

  static WeatherPalette resolve(DashboardWeather weather, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hour = DateTime.now().hour;
    final isNight = !weather.isDay || hour >= 20 || hour < 6;

    if (isNight) {
      return WeatherPalette(
        gradient: isDark
            ? [const Color(0xFF1A237E), const Color(0xFF0D1B4C)]
            : [const Color(0xFF5C6BC0), const Color(0xFF3949AB)],
        text: const Color(0xFFE8EAF6),
        shadow: const Color(0xFF3949AB),
      );
    }

    return switch (weather.kind) {
      DashboardWeatherKind.sunny => WeatherPalette(
          gradient: hour < 11
              ? (isDark
                  ? [const Color(0xFF5D4037), const Color(0xFFE65100)]
                  : [const Color(0xFFFFE082), const Color(0xFFFFB74D)])
              : (isDark
                  ? [const Color(0xFF1565C0), const Color(0xFF0277BD)]
                  : [const Color(0xFF64B5F6), const Color(0xFF42A5F5)]),
          text: isDark ? const Color(0xFFFFF8E1) : const Color(0xFF1A1A1A),
          shadow: const Color(0xFF42A5F5),
        ),
      DashboardWeatherKind.partlyCloudy => WeatherPalette(
          gradient: isDark
              ? [const Color(0xFF37474F), const Color(0xFF546E7A)]
              : [const Color(0xFFB3E5FC), const Color(0xFF81D4FA)],
          text: isDark ? const Color(0xFFECEFF1) : const Color(0xFF01579B),
          shadow: const Color(0xFF0288D1),
        ),
      DashboardWeatherKind.cloudy || DashboardWeatherKind.foggy => WeatherPalette(
          gradient: isDark
              ? [const Color(0xFF455A64), const Color(0xFF37474F)]
              : [const Color(0xFFCFD8DC), const Color(0xFF90A4AE)],
          text: isDark ? const Color(0xFFECEFF1) : const Color(0xFF37474F),
          shadow: const Color(0xFF546E7A),
        ),
      DashboardWeatherKind.rainy || DashboardWeatherKind.stormy => WeatherPalette(
          gradient: isDark
              ? [const Color(0xFF1A237E), const Color(0xFF283593)]
              : [const Color(0xFF90CAF9), const Color(0xFF5C6BC0)],
          text: isDark ? const Color(0xFFE3F2FD) : const Color(0xFF1A237E),
          shadow: const Color(0xFF3949AB),
        ),
      DashboardWeatherKind.snowy => WeatherPalette(
          gradient: isDark
              ? [const Color(0xFF37474F), const Color(0xFF546E7A)]
              : [const Color(0xFFECEFF1), const Color(0xFFB0BEC5)],
          text: isDark ? const Color(0xFFECEFF1) : const Color(0xFF455A64),
          shadow: const Color(0xFF78909C),
        ),
    };
  }
}
