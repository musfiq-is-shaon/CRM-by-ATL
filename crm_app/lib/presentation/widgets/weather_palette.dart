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
            ? [const Color(0xFF16213E), const Color(0xFF0F1B3D)]
            : [const Color(0xFF3E4C8A), const Color(0xFF222C5C)],
        text: const Color(0xFFE8EAF6),
        shadow: const Color(0xFF283593),
      );
    }

    return switch (weather.kind) {
      DashboardWeatherKind.sunny => WeatherPalette(
          gradient: hour < 11
              ? (isDark
                  ? [const Color(0xFF7A4A12), const Color(0xFFB2620E)]
                  : [const Color(0xFFFFC15E), const Color(0xFFFF9A3D)])
              : (isDark
                  ? [const Color(0xFF0D47A1), const Color(0xFF1565C0)]
                  : [const Color(0xFF4FACFE), const Color(0xFF2F80ED)]),
          text: Colors.white,
          shadow: hour < 11 ? const Color(0xFFFF9A3D) : const Color(0xFF2F80ED),
        ),
      DashboardWeatherKind.partlyCloudy => WeatherPalette(
          gradient: isDark
              ? [const Color(0xFF2C4A63), const Color(0xFF1E3448)]
              : [const Color(0xFF56A8E8), const Color(0xFF3D7EC9)],
          text: Colors.white,
          shadow: const Color(0xFF3D7EC9),
        ),
      DashboardWeatherKind.cloudy || DashboardWeatherKind.foggy => WeatherPalette(
          gradient: isDark
              ? [const Color(0xFF37474F), const Color(0xFF263238)]
              : [const Color(0xFF7F96A8), const Color(0xFF5B7285)],
          text: Colors.white,
          shadow: const Color(0xFF5B7285),
        ),
      DashboardWeatherKind.rainy || DashboardWeatherKind.stormy => WeatherPalette(
          gradient: isDark
              ? [const Color(0xFF1F2A56), const Color(0xFF141C3F)]
              : [const Color(0xFF4B5FA8), const Color(0xFF303F77)],
          text: const Color(0xFFEAF0FF),
          shadow: const Color(0xFF303F77),
        ),
      DashboardWeatherKind.snowy => WeatherPalette(
          gradient: isDark
              ? [const Color(0xFF34495E), const Color(0xFF22303F)]
              : [const Color(0xFF8FA8C8), const Color(0xFF6A84A8)],
          text: Colors.white,
          shadow: const Color(0xFF6A84A8),
        ),
    };
  }
}
