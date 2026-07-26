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

  /// Reserved slot so loading → data never shifts cards below.
  static const double slotHeight = _CompactWeatherCard._height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(dashboardWeatherProvider);
    final weather = weatherAsync.asData?.value;
    final showPlaceholder = weatherAsync.isLoading && weather == null;

    if (!showPlaceholder && weather == null) {
      final failed = weatherAsync.hasError || weatherAsync.hasValue;
      if (!failed) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: SizedBox(
          height: slotHeight,
          width: double.infinity,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              onTap: () =>
                  ref.read(dashboardWeatherProvider.notifier).refresh(),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Center(
                child: Text(
                  'Weather unavailable · Tap to retry',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.15,
        child: SizedBox(
          height: slotHeight,
          width: double.infinity,
          child: showPlaceholder
              ? const ShimmerLoading(
                  height: slotHeight,
                  borderRadius: AppRadius.lg,
                )
              : _CompactWeatherCard(weather: weather!),
        ),
      ),
    );
  }
}

class _CompactWeatherCard extends StatelessWidget {
  const _CompactWeatherCard({required this.weather});

  final DashboardWeather weather;

  static const _height = 104.0;
  static const _animSize = 66.0;

  @override
  Widget build(BuildContext context) {
    final palette = WeatherPalette.resolve(weather, context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radius = 20.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => WeatherForecastPage.open(context),
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: _height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.gradient,
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(alpha: isDark ? 0.3 : 0.22),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              children: [
                // Soft highlight wash in the top-left corner for depth.
                Positioned(
                  top: -46,
                  left: -30,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.10 : 0.30),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      // Animation sits in a frosted circular well.
                      Container(
                        width: _animSize + 14,
                        height: _animSize + 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              Colors.white.withValues(alpha: isDark ? 0.08 : 0.28),
                        ),
                        alignment: Alignment.center,
                        child: RepaintBoundary(
                          child: WeatherMoodAnimation(
                            kind: weather.kind,
                            size: _animSize,
                            isDay: weather.isDay,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: palette.text.withValues(alpha: 0.75),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    weather.locationLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      height: 1.1,
                                      color:
                                          palette.text.withValues(alpha: 0.78),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              weather.conditionLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                                letterSpacing: -0.1,
                                color: palette.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              weather.smartSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: palette.text.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${weather.temperatureC.round()}°',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              letterSpacing: -1.2,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _MetaChip(
                            palette: palette,
                            isDark: isDark,
                            label: _subtitle(weather),
                            precipitation: _precipitation(weather),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _subtitle(DashboardWeather weather) {
    if (weather.highC != null && weather.lowC != null) {
      return '${weather.highC!.round()}° / ${weather.lowC!.round()}°';
    }
    if (weather.feelsLikeC != null) {
      return 'Feels ${weather.feelsLikeC!.round()}°';
    }
    return '';
  }

  static int? _precipitation(DashboardWeather weather) {
    if (weather.hourly.isEmpty) return null;
    return weather.hourly.first.precipitationChance;
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.palette,
    required this.isDark,
    required this.label,
    required this.precipitation,
  });

  final WeatherPalette palette;
  final bool isDark;
  final String label;
  final int? precipitation;

  @override
  Widget build(BuildContext context) {
    final showRain = precipitation != null && precipitation! > 0;
    if (label.isEmpty && !showRain) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showRain) ...[
            Icon(
              Icons.water_drop_rounded,
              size: 10,
              color: palette.text.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 2),
            Text(
              '$precipitation%',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: palette.text.withValues(alpha: 0.9),
              ),
            ),
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  '·',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: palette.text.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: palette.text.withValues(alpha: 0.9),
              ),
            ),
        ],
      ),
    );
  }
}
