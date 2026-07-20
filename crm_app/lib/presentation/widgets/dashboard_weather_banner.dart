import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/models/weather_model.dart';
import '../pages/dashboard/weather_forecast_page.dart';
import '../providers/dashboard_weather_provider.dart';
import 'loading_widget.dart';
import 'weather_mood_animation.dart';
import 'weather_palette.dart';

class DashboardWeatherBanner extends ConsumerWidget {
  const DashboardWeatherBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(dashboardWeatherProvider);

    return weatherAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.md),
        child: ShimmerLoading(height: 76, borderRadius: AppRadius.lg),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (weather) {
        if (weather == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: _CompactWeatherCard(weather: weather),
        );
      },
    );
  }
}

class _CompactWeatherCard extends StatelessWidget {
  const _CompactWeatherCard({required this.weather});

  final DashboardWeather weather;

  static const _height = 76.0;
  static const _animSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final palette = WeatherPalette.resolve(weather, context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => WeatherForecastPage.open(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          height: _height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.gradient,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: palette.shadow.withValues(alpha: isDark ? 0.25 : 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: palette.text.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            weather.locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: palette.text.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weather.conditionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    if (_subtitle(weather).isNotEmpty)
                      Text(
                        _subtitle(weather),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.text.withValues(alpha: 0.75),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${weather.temperatureC.round()}°',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  letterSpacing: -0.5,
                  color: palette.text,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              WeatherMoodAnimation(
                kind: weather.kind,
                size: _animSize,
                isDay: weather.isDay,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitle(DashboardWeather weather) {
    final parts = <String>[];
    if (weather.highC != null && weather.lowC != null) {
      parts.add('H:${weather.highC!.round()}° L:${weather.lowC!.round()}°');
    }
    if (weather.feelsLikeC != null) {
      parts.add('Feels ${weather.feelsLikeC!.round()}°');
    } else if (weather.humidity != null) {
      parts.add('${weather.humidity}% humidity');
    }
    return parts.join(' · ');
  }
}
