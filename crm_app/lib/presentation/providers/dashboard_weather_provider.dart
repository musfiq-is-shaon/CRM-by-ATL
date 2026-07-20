import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/weather_service.dart';
import '../../data/models/weather_model.dart';
import 'dashboard_live_location_provider.dart';

final dashboardWeatherProvider =
    AsyncNotifierProvider<DashboardWeatherNotifier, DashboardWeather?>(
  DashboardWeatherNotifier.new,
);

class DashboardWeatherNotifier extends AsyncNotifier<DashboardWeather?> {
  @override
  Future<DashboardWeather?> build() async {
    ref.watch(dashboardVisitLiveLocationRefreshTickProvider);
    return ref.read(weatherServiceProvider).fetchCurrentWeather();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<DashboardWeather?>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(weatherServiceProvider).fetchCurrentWeather(forceRefresh: true),
    );
  }
}
