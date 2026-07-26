import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/weather_service.dart';
import '../../data/models/weather_model.dart';

final dashboardWeatherProvider =
    AsyncNotifierProvider<DashboardWeatherNotifier, DashboardWeather?>(
  DashboardWeatherNotifier.new,
);

class DashboardWeatherNotifier extends AsyncNotifier<DashboardWeather?> {
  @override
  Future<DashboardWeather?> build() async {
    // Do not watch dashboard-visit ticks here — that invalidated weather on every
    // tab switch and flashed loading UI (layout shake under the hero).
    return ref.read(weatherServiceProvider).fetchCurrentWeather();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<DashboardWeather?>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(weatherServiceProvider).fetchCurrentWeather(forceRefresh: true),
    );
  }
}
