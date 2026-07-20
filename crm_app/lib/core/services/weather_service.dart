import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../data/models/weather_model.dart';
import 'location_service.dart';

/// Free weather via [Open-Meteo](https://open-meteo.com/) — no API key required.
class WeatherService {
  WeatherService({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  final LocationService _locationService;
  DashboardWeather? _cache;
  DateTime? _cacheAt;
  static const _cacheTtl = Duration(minutes: 20);

  Future<DashboardWeather?> fetchCurrentWeather({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cache != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return _cache;
    }

    final position = await _resolvePosition();
    if (position == null) return _cache;

    try {
      final weather = await _fetchOpenMeteo(position);
      _cache = weather;
      _cacheAt = DateTime.now();
      return weather;
    } catch (e) {
      if (kDebugMode) debugPrint('WeatherService.fetchCurrentWeather: $e');
      return _cache;
    }
  }

  Future<DashboardWeather> _fetchOpenMeteo(Position position) async {
    final weatherUri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': '${position.latitude}',
        'longitude': '${position.longitude}',
        'current': [
          'temperature_2m',
          'apparent_temperature',
          'weather_code',
          'relative_humidity_2m',
          'is_day',
          'wind_speed_10m',
        ].join(','),
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
          'precipitation_probability_max',
        ].join(','),
        'hourly': [
          'temperature_2m',
          'weather_code',
          'precipitation_probability',
          'is_day',
        ].join(','),
        'forecast_days': '7',
        'timezone': 'auto',
      },
    );
    final geoUri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/reverse',
      {
        'latitude': '${position.latitude}',
        'longitude': '${position.longitude}',
        'language': 'en',
        'count': '1',
      },
    );

    final responses = await Future.wait([
      http.get(weatherUri).timeout(const Duration(seconds: 12)),
      http.get(geoUri).timeout(const Duration(seconds: 8)),
    ]);

    if (responses[0].statusCode != 200) {
      throw Exception('Open-Meteo forecast failed (${responses[0].statusCode})');
    }

    final weatherJson = jsonDecode(responses[0].body) as Map<String, dynamic>;
    final current = weatherJson['current'] as Map<String, dynamic>?;
    if (current == null) throw Exception('Open-Meteo missing current block');

    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    final dailyPoints = _parseDailyPoints(weatherJson['daily']);
    final hourly = _parseHourlyPoints(weatherJson['hourly'], limit: 24);

    var locationLabel = '';
    if (responses[1].statusCode == 200) {
      final geoJson = jsonDecode(responses[1].body) as Map<String, dynamic>;
      final results = geoJson['results'] as List<dynamic>?;
      if (results != null && results.isNotEmpty) {
        final place = results.first as Map<String, dynamic>;
        locationLabel = _formatPlace(place);
      }
    }
    if (locationLabel.isEmpty) {
      locationLabel = await LocationService.placeLabelFromCoordinateString(
        LocationService.formatCoordinatesForStorage(
          position.latitude,
          position.longitude,
        ),
      );
    }
    if (locationLabel.isEmpty) locationLabel = 'Your location';

    return DashboardWeather(
      temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      kind: DashboardWeather.kindFromWmoCode(code),
      locationLabel: locationLabel,
      weatherCode: code,
      conditionText: DashboardWeather.labelFromWmoCode(code),
      dataSourceLabel: 'Open-Meteo',
      feelsLikeC: (current['apparent_temperature'] as num?)?.toDouble(),
      humidity: (current['relative_humidity_2m'] as num?)?.toInt(),
      highC: dailyPoints.isNotEmpty ? dailyPoints.first.highC : null,
      lowC: dailyPoints.isNotEmpty ? dailyPoints.first.lowC : null,
      isDay: (current['is_day'] as num?)?.toInt() == 1,
      windSpeedKmh: (current['wind_speed_10m'] as num?)?.toDouble(),
      hourly: hourly,
      daily: dailyPoints,
    );
  }

  static List<WeatherHourlyPoint> _parseHourlyPoints(
    dynamic raw, {
    int limit = 24,
  }) {
    if (raw is! Map<String, dynamic>) return const [];

    final times = raw['time'] as List<dynamic>?;
    final temps = raw['temperature_2m'] as List<dynamic>?;
    final codes = raw['weather_code'] as List<dynamic>?;
    final precip = raw['precipitation_probability'] as List<dynamic>?;
    final isDayList = raw['is_day'] as List<dynamic>?;
    if (times == null || temps == null || codes == null) return const [];

    final now = DateTime.now();
    final points = <WeatherHourlyPoint>[];
    for (var i = 0; i < times.length; i++) {
      final parsed = DateTime.tryParse(times[i].toString());
      if (parsed == null) continue;
      if (parsed.isBefore(now.subtract(const Duration(minutes: 30)))) continue;

      final wmo = (codes[i] as num?)?.toInt() ?? 0;
      points.add(
        WeatherHourlyPoint(
          time: parsed.toLocal(),
          temperatureC: (temps[i] as num?)?.toDouble() ?? 0,
          kind: DashboardWeather.kindFromWmoCode(wmo),
          weatherCode: wmo,
          conditionText: DashboardWeather.labelFromWmoCode(wmo),
          precipitationChance: (precip != null && i < precip.length)
              ? (precip[i] as num?)?.toInt()
              : null,
          isDay: isDayList != null && i < isDayList.length
              ? (isDayList[i] as num?)?.toInt() == 1
              : true,
        ),
      );
      if (points.length >= limit) break;
    }
    return points;
  }

  static List<WeatherDailyPoint> _parseDailyPoints(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const [];

    final dates = raw['time'] as List<dynamic>?;
    final highs = raw['temperature_2m_max'] as List<dynamic>?;
    final lows = raw['temperature_2m_min'] as List<dynamic>?;
    final codes = raw['weather_code'] as List<dynamic>?;
    final precip = raw['precipitation_probability_max'] as List<dynamic>?;
    if (dates == null || highs == null || lows == null || codes == null) {
      return const [];
    }

    final points = <WeatherDailyPoint>[];
    for (var i = 0; i < dates.length; i++) {
      final parsed = DateTime.tryParse(dates[i].toString());
      if (parsed == null) continue;
      final wmo = (codes[i] as num?)?.toInt() ?? 0;
      points.add(
        WeatherDailyPoint(
          date: parsed.toLocal(),
          highC: (highs[i] as num?)?.toDouble() ?? 0,
          lowC: (lows[i] as num?)?.toDouble() ?? 0,
          kind: DashboardWeather.kindFromWmoCode(wmo),
          weatherCode: wmo,
          conditionText: DashboardWeather.labelFromWmoCode(wmo),
          precipitationChance: (precip != null && i < precip.length)
              ? (precip[i] as num?)?.toInt()
              : null,
        ),
      );
    }
    return points;
  }

  Future<Position?> _resolvePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;

      return _locationService.fetchHighAccuracyPosition();
    } catch (_) {
      return null;
    }
  }

  static String _formatPlace(Map<String, dynamic> place) {
    final name = (place['name'] as String?)?.trim() ?? '';
    final admin1 = (place['admin1'] as String?)?.trim() ?? '';
    final country = (place['country'] as String?)?.trim() ?? '';
    if (name.isNotEmpty && admin1.isNotEmpty && name != admin1) {
      return '$name, $admin1';
    }
    if (name.isNotEmpty && country.isNotEmpty) return '$name, $country';
    return name.isNotEmpty ? name : admin1;
  }
}

final weatherServiceProvider = Provider<WeatherService>(
  (ref) => WeatherService(locationService: ref.watch(locationServiceProvider)),
);
