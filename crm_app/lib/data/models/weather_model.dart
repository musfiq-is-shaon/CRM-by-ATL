enum DashboardWeatherKind {
  sunny,
  partlyCloudy,
  cloudy,
  rainy,
  stormy,
  foggy,
  snowy,
}

class WeatherHourlyPoint {
  const WeatherHourlyPoint({
    required this.time,
    required this.temperatureC,
    required this.kind,
    required this.weatherCode,
    this.conditionText,
    this.precipitationChance,
    this.isDay = true,
  });

  final DateTime time;
  final double temperatureC;
  final DashboardWeatherKind kind;
  final int weatherCode;
  final String? conditionText;
  final int? precipitationChance;
  final bool isDay;

  String get conditionLabel =>
      conditionText ?? DashboardWeather.labelFromWmoCode(weatherCode);
}

class WeatherDailyPoint {
  const WeatherDailyPoint({
    required this.date,
    required this.highC,
    required this.lowC,
    required this.kind,
    required this.weatherCode,
    this.conditionText,
    this.precipitationChance,
  });

  final DateTime date;
  final double highC;
  final double lowC;
  final DashboardWeatherKind kind;
  final int weatherCode;
  final String? conditionText;
  final int? precipitationChance;

  String get conditionLabel =>
      conditionText ?? DashboardWeather.labelFromWmoCode(weatherCode);
}

class DashboardWeather {
  const DashboardWeather({
    required this.temperatureC,
    required this.kind,
    required this.locationLabel,
    required this.weatherCode,
    this.conditionText,
    this.dataSourceLabel,
    this.feelsLikeC,
    this.humidity,
    this.highC,
    this.lowC,
    this.isDay = true,
    this.windSpeedKmh,
    this.hourly = const [],
    this.daily = const [],
  });

  final double temperatureC;
  final DashboardWeatherKind kind;
  final String locationLabel;
  final int weatherCode;
  final String? conditionText;
  final String? dataSourceLabel;
  final double? feelsLikeC;
  final int? humidity;
  final double? highC;
  final double? lowC;
  final bool isDay;
  final double? windSpeedKmh;
  final List<WeatherHourlyPoint> hourly;
  final List<WeatherDailyPoint> daily;

  String get conditionLabel =>
      conditionText ?? labelFromWmoCode(weatherCode);

  static String labelFromWmoCode(int code) {
    return switch (code) {
      0 => 'Clear sky',
      1 => 'Mainly clear',
      2 => 'Partly cloudy',
      3 => 'Overcast',
      45 => 'Fog',
      48 => 'Depositing rime fog',
      51 => 'Light drizzle',
      53 => 'Drizzle',
      55 => 'Dense drizzle',
      56 => 'Freezing drizzle',
      57 => 'Dense freezing drizzle',
      61 => 'Slight rain',
      63 => 'Rain',
      65 => 'Heavy rain',
      66 => 'Freezing rain',
      67 => 'Heavy freezing rain',
      71 => 'Slight snow',
      73 => 'Snow',
      75 => 'Heavy snow',
      77 => 'Snow grains',
      80 => 'Rain showers',
      81 => 'Moderate showers',
      82 => 'Violent showers',
      85 => 'Snow showers',
      86 => 'Heavy snow showers',
      95 => 'Thunderstorm',
      96 => 'Thunderstorm with hail',
      99 => 'Thunderstorm with heavy hail',
      _ => 'Cloudy',
    };
  }

  static DashboardWeatherKind kindFromWmoCode(int code) {
    if (code == 0 || code == 1) return DashboardWeatherKind.sunny;
    if (code == 2) return DashboardWeatherKind.partlyCloudy;
    if (code == 3) return DashboardWeatherKind.cloudy;
    if (code == 45 || code == 48) return DashboardWeatherKind.foggy;
    if (code >= 51 && code <= 67) return DashboardWeatherKind.rainy;
    if (code >= 71 && code <= 77) return DashboardWeatherKind.snowy;
    if (code >= 80 && code <= 82) return DashboardWeatherKind.rainy;
    if (code >= 85 && code <= 86) return DashboardWeatherKind.snowy;
    if (code >= 95) return DashboardWeatherKind.stormy;
    return DashboardWeatherKind.cloudy;
  }
}
