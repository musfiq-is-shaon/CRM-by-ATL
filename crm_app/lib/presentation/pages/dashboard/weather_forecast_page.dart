import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/weather_model.dart';
import '../../providers/dashboard_weather_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/weather_mood_animation.dart';
import '../../widgets/weather_palette.dart';

class WeatherForecastPage extends ConsumerWidget {
  const WeatherForecastPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const WeatherForecastPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(dashboardWeatherProvider);
    final bg = AppThemeColors.backgroundColor(context);

    return Scaffold(
      backgroundColor: bg,
      body: weatherAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const _ForecastSkeleton(),
        error: (_, _) => _ErrorBody(
          onRetry: () => ref.read(dashboardWeatherProvider.notifier).refresh(),
        ),
        data: (weather) {
          if (weather == null) {
            return _ErrorBody(
              onRetry: () =>
                  ref.read(dashboardWeatherProvider.notifier).refresh(),
            );
          }
          return _ForecastBody(weather: weather);
        },
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppThemeColors.pagePaddingAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: AppSpacing.md),
            const Text('Weather unavailable'),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ForecastSkeleton extends StatelessWidget {
  const _ForecastSkeleton();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: topInset + 252,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: kToolbarHeight),
                  ShimmerLoading(width: 160, height: 14),
                  Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerLoading(width: 100, height: 18),
                            SizedBox(height: 8),
                            ShimmerLoading(width: 88, height: 44),
                            SizedBox(height: 8),
                            ShimmerLoading(width: 140, height: 12),
                          ],
                        ),
                      ),
                      ShimmerLoading(
                        width: 84,
                        height: 84,
                        borderRadius: AppRadius.lg,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: AppThemeColors.pagePaddingAll,
          sliver: SliverList(
            delegate: SliverChildListDelegate(const [
              ShimmerLoading(width: 120, height: 16),
              SizedBox(height: AppSpacing.sm),
              ShimmerCard(height: 64),
              SizedBox(height: AppSpacing.sm),
              ShimmerCard(height: 64),
              SizedBox(height: AppSpacing.sm),
              ShimmerCard(height: 64),
              SizedBox(height: AppSpacing.md),
              ShimmerLoading(width: 100, height: 16),
              SizedBox(height: AppSpacing.sm),
              ShimmerCard(height: 140),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ForecastBody extends ConsumerStatefulWidget {
  const _ForecastBody({required this.weather});

  final DashboardWeather weather;

  @override
  ConsumerState<_ForecastBody> createState() => _ForecastBodyState();
}

class _ForecastBodyState extends ConsumerState<_ForecastBody> {
  @override
  Widget build(BuildContext context) {
    final weather = widget.weather;
    final palette = WeatherPalette.resolve(weather, context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    return RefreshIndicator(
      onRefresh: () => ref.read(dashboardWeatherProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 252,
            pinned: true,
            stretch: true,
            backgroundColor: palette.gradient.last,
            foregroundColor: palette.text,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: ClipRect(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: palette.gradient,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          left: 20,
                          right: 20,
                          top: kToolbarHeight + 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: palette.text.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      weather.locationLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: palette.text
                                            .withValues(alpha: 0.92),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (weather.lastUpdated != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 20),
                                  child: Text(
                                    'Updated ${DateFormat.jm().format(weather.lastUpdated!)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: palette.text
                                          .withValues(alpha: 0.72),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 16,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final narrow = constraints.maxWidth < 320;
                              final animSize = narrow ? 72.0 : 84.0;
                              final tempSize = narrow ? 48.0 : 56.0;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${weather.temperatureC.round()}°',
                                    style: TextStyle(
                                      fontSize: tempSize,
                                      fontWeight: FontWeight.w300,
                                      height: 1,
                                      color: palette.text,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          weather.conditionLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: narrow ? 15 : 17,
                                            fontWeight: FontWeight.w700,
                                            color: palette.text,
                                          ),
                                        ),
                                        if (weather.feelsLikeC != null)
                                          Text(
                                            'Feels like ${weather.feelsLikeC!.round()}°',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: palette.text
                                                  .withValues(alpha: 0.85),
                                            ),
                                          ),
                                        if (weather.highC != null &&
                                            weather.lowC != null)
                                          Text(
                                            'H:${weather.highC!.round()}° L:${weather.lowC!.round()}°',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: palette.text
                                                  .withValues(alpha: 0.85),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  WeatherMoodAnimation(
                                    kind: weather.kind,
                                    size: animSize,
                                    isDay: weather.isDay,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: AppThemeColors.pagePaddingAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (weather.alerts.isNotEmpty) ...[
                    _WeatherAlertCard(alert: weather.alerts.first),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _WeatherInsightCard(weather: weather),
                  const SizedBox(height: AppSpacing.md),
                  _StatsRow(weather: weather),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Next hours',
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (weather.hourly.isEmpty)
                    Text('Hourly forecast unavailable', style: TextStyle(color: textSecondary))
                  else
                    SizedBox(
                      height: 118,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: weather.hourly.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, i) =>
                            _HourlyTile(point: weather.hourly[i]),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '${weather.daily.length}-day forecast',
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (weather.daily.isEmpty)
                    Text('Daily forecast unavailable', style: TextStyle(color: textSecondary))
                  else
                    CRMCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < weather.daily.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            _DailyRow(point: weather.daily[i]),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Powered by ${weather.dataSourceLabel ?? 'WeatherAPI.com'}',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherInsightCard extends StatelessWidget {
  const _WeatherInsightCard({required this.weather});

  final DashboardWeather weather;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 17, color: cs.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weather insight',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
                Text(
                  weather.smartSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (weather.sunrise != null || weather.sunset != null)
            Text(
              weather.isDay
                  ? 'Sunset\n${weather.sunset ?? '—'}'
                  : 'Sunrise\n${weather.sunrise ?? '—'}',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 10,
                height: 1.25,
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _WeatherAlertCard extends StatelessWidget {
  const _WeatherAlertCard({required this.alert});

  final WeatherAlert alert;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.event ?? 'Weather alert',
                  style: TextStyle(
                    color: cs.error,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.headline,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.weather});

  final DashboardWeather weather;

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final items = <(IconData, String, String)>[
      if (weather.humidity != null)
        (Icons.water_drop_outlined, 'Humidity', '${weather.humidity}%'),
      if (weather.windSpeedKmh != null)
        (
          Icons.air_rounded,
          'Wind ${weather.windDirection ?? ''}'.trim(),
          '${weather.windSpeedKmh!.round()} km/h',
        ),
      if (weather.uvIndex != null)
        (Icons.wb_sunny_outlined, 'UV ${weather.uvLabel}', '${weather.uvIndex}'),
      if (weather.visibilityKm != null)
        (
          Icons.visibility_outlined,
          'Visibility',
          '${weather.visibilityKm!.toStringAsFixed(1)} km',
        ),
      if (weather.pressureMb != null)
        (
          Icons.speed_rounded,
          'Pressure',
          '${weather.pressureMb!.round()} mb',
        ),
      if (weather.windGustKmh != null)
        (
          Icons.storm_outlined,
          'Gusts',
          '${weather.windGustKmh!.round()} km/h',
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 2;
        final width =
            (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: CRMCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(item.$1, size: 19, color: textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: textSecondary,
                              ),
                            ),
                            Text(
                              item.$3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HourlyTile extends StatelessWidget {
  const _HourlyTile({required this.point});

  final WeatherHourlyPoint point;

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final label = DateFormat.jm().format(point.time);

    return CRMCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: textSecondary),
            ),
            const SizedBox(height: 4),
            WeatherMoodAnimation(
              kind: point.kind,
              size: 32,
              isDay: point.isDay,
            ),
            const SizedBox(height: 4),
            Text(
              '${point.temperatureC.round()}°',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (point.precipitationChance != null)
              Text(
                '${point.precipitationChance}%',
                style: TextStyle(fontSize: 9, color: textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({required this.point});

  final WeatherDailyPoint point;

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEE').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppThemeColors.textSecondaryColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              _dayLabel(point.date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          WeatherMoodAnimation(
            kind: point.kind,
            size: 36,
            isDay: true,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              point.conditionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ),
          if (point.precipitationChance != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '${point.precipitationChance}%',
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            '${point.lowC.round()}°',
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 26,
            child: Text(
              '${point.highC.round()}°',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
