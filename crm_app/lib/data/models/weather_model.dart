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
    this.feelsLikeC,
    this.humidity,
    this.windSpeedKmh,
  });

  final DateTime time;
  final double temperatureC;
  final DashboardWeatherKind kind;
  final int weatherCode;
  final String? conditionText;
  final int? precipitationChance;
  final bool isDay;
  final double? feelsLikeC;
  final int? humidity;
  final double? windSpeedKmh;

  String get conditionLabel =>
      conditionText ?? DashboardWeather.labelFromWeatherApiCode(weatherCode);
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
    this.averageC,
    this.maxWindKmh,
    this.averageHumidity,
    this.totalPrecipitationMm,
    this.sunrise,
    this.sunset,
  });

  final DateTime date;
  final double highC;
  final double lowC;
  final DashboardWeatherKind kind;
  final int weatherCode;
  final String? conditionText;
  final int? precipitationChance;
  final double? averageC;
  final double? maxWindKmh;
  final int? averageHumidity;
  final double? totalPrecipitationMm;
  final String? sunrise;
  final String? sunset;

  String get conditionLabel =>
      conditionText ?? DashboardWeather.labelFromWeatherApiCode(weatherCode);
}

class WeatherAlert {
  const WeatherAlert({
    required this.headline,
    this.event,
    this.severity,
    this.urgency,
    this.areas,
    this.effective,
    this.expires,
    this.description,
    this.instruction,
  });

  final String headline;
  final String? event;
  final String? severity;
  final String? urgency;
  final String? areas;
  final DateTime? effective;
  final DateTime? expires;
  final String? description;
  final String? instruction;
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
    this.windDirection,
    this.windGustKmh,
    this.pressureMb,
    this.precipitationMm,
    this.visibilityKm,
    this.cloudCover,
    this.uvIndex,
    this.lastUpdated,
    this.sunrise,
    this.sunset,
    this.hourly = const [],
    this.daily = const [],
    this.alerts = const [],
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
  final String? windDirection;
  final double? windGustKmh;
  final double? pressureMb;
  final double? precipitationMm;
  final double? visibilityKm;
  final int? cloudCover;
  final double? uvIndex;
  final DateTime? lastUpdated;
  final String? sunrise;
  final String? sunset;
  final List<WeatherHourlyPoint> hourly;
  final List<WeatherDailyPoint> daily;
  final List<WeatherAlert> alerts;

  String get conditionLabel =>
      conditionText ?? labelFromWeatherApiCode(weatherCode);

  String get smartSummary {
    if (alerts.isNotEmpty) return alerts.first.headline;
    WeatherHourlyPoint? nextRain;
    for (final point in hourly) {
      if ((point.precipitationChance ?? 0) >= 55) {
        nextRain = point;
        break;
      }
    }
    if (nextRain != null) {
      final hour = nextRain.time.hour;
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      return 'Rain possible around $hour12 $period';
    }
    if ((uvIndex ?? 0) >= 6 && isDay) return 'High UV — use sun protection';
    if ((windGustKmh ?? 0) >= 40) return 'Strong gusts possible';
    if ((visibilityKm ?? 99) < 3) return 'Low visibility nearby';
    return isDay ? 'Current conditions near you' : 'Tonight near you';
  }

  String get uvLabel {
    final uv = uvIndex ?? 0;
    if (uv < 3) return 'Low';
    if (uv < 6) return 'Moderate';
    if (uv < 8) return 'High';
    if (uv < 11) return 'Very high';
    return 'Extreme';
  }

  /// WeatherAPI condition code mapping:
  /// https://www.weatherapi.com/docs/weather_conditions.json
  static DashboardWeatherKind kindFromWeatherApiCode(int code) {
    if (code == 1000) return DashboardWeatherKind.sunny;
    if (code == 1003) return DashboardWeatherKind.partlyCloudy;
    if (code == 1006 || code == 1009) return DashboardWeatherKind.cloudy;
    if ({1030, 1135, 1147}.contains(code)) return DashboardWeatherKind.foggy;
    if ({
      1066, 1069, 1114, 1117, 1204, 1207, 1210, 1213, 1216, 1219,
      1222, 1225, 1237, 1255, 1258, 1261, 1264,
    }.contains(code)) {
      return DashboardWeatherKind.snowy;
    }
    if ({1087, 1273, 1276, 1279, 1282}.contains(code)) {
      return DashboardWeatherKind.stormy;
    }
    if ({
      1063, 1072, 1150, 1153, 1168, 1171, 1180, 1183, 1186, 1189,
      1192, 1195, 1198, 1201, 1240, 1243, 1246, 1249, 1252,
    }.contains(code)) {
      return DashboardWeatherKind.rainy;
    }
    return DashboardWeatherKind.cloudy;
  }

  static String labelFromWeatherApiCode(int code) {
    return switch (kindFromWeatherApiCode(code)) {
      DashboardWeatherKind.sunny => 'Clear',
      DashboardWeatherKind.partlyCloudy => 'Partly cloudy',
      DashboardWeatherKind.cloudy => 'Cloudy',
      DashboardWeatherKind.rainy => 'Rain',
      DashboardWeatherKind.stormy => 'Thunderstorm',
      DashboardWeatherKind.foggy => 'Fog',
      DashboardWeatherKind.snowy => 'Snow',
    };
  }
}
