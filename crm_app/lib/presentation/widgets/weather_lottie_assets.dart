import '../../data/models/weather_model.dart';

/// Bundled LottieFiles weather animations (Lottie Simple License).
abstract final class WeatherLottieAssets {
  static const _base = 'assets/lottie/weather';

  /// Full icon set — reliable fallback when per-kind extract fails to render.
  static const full = '$_base/full_weather.json';

  static const sunny = '$_base/sunny.json';
  static const partlyCloudy = '$_base/partly_cloudy.json';
  static const cloudy = '$_base/cloudy.json';
  static const foggy = '$_base/foggy.json';
  static const rainy = '$_base/rainy.json';
  static const stormy = '$_base/stormy.json';
  static const snowy = '$_base/snowy.json';

  static String forKind(DashboardWeatherKind kind) => switch (kind) {
        DashboardWeatherKind.sunny => sunny,
        DashboardWeatherKind.partlyCloudy => partlyCloudy,
        DashboardWeatherKind.cloudy => cloudy,
        DashboardWeatherKind.foggy => foggy,
        DashboardWeatherKind.rainy => rainy,
        DashboardWeatherKind.stormy => stormy,
        DashboardWeatherKind.snowy => snowy,
      };
}
