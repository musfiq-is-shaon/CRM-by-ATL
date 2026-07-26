import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../data/models/weather_model.dart';
import '../config/crm_env_config.dart';
import 'location_service.dart';

/// WeatherAPI forecast client.
///
/// One `/v1/forecast.json` call returns location, current conditions, hourly
/// forecast, daily forecast, astronomy and government alerts.
class WeatherService {
  WeatherService({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  final LocationService _locationService;
  DashboardWeather? _cache;
  DateTime? _cacheAt;
  Position? _cachePosition;
  static const _cacheTtl = Duration(minutes: 12);
  /// Invalidate cache if the device has moved this far since last fetch.
  static const _cacheMoveInvalidateMeters = 2500.0;

  Future<DashboardWeather?> fetchCurrentWeather({bool forceRefresh = false}) async {
    final position = await _resolvePosition();
    if (position == null) return forceRefresh ? null : _cache;

    if (!forceRefresh &&
        _cache != null &&
        _cacheAt != null &&
        _cachePosition != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      final moved = Geolocator.distanceBetween(
        _cachePosition!.latitude,
        _cachePosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (moved < _cacheMoveInvalidateMeters) {
        return _cache;
      }
    }

    try {
      final weather = await _fetchWeatherApi(position);
      _cache = weather;
      _cacheAt = DateTime.now();
      _cachePosition = position;
      return weather;
    } catch (e) {
      if (kDebugMode) debugPrint('WeatherService.fetchCurrentWeather: $e');
      return _cache;
    }
  }

  Future<DashboardWeather> _fetchWeatherApi(Position position) async {
    final key = CrmEnvConfig.weatherApiKey;
    if (key.isEmpty) {
      throw StateError('WEATHER_API_KEY is not configured');
    }

    // Keep enough decimals so WeatherAPI does not snap to a distant city.
    final lat = position.latitude.toStringAsFixed(5);
    final lon = position.longitude.toStringAsFixed(5);
    final uri = Uri.https('api.weatherapi.com', '/v1/forecast.json', {
      'key': key,
      'q': '$lat,$lon',
      // WeatherAPI free plan supports the next three forecast days.
      'days': '3',
      'aqi': 'no',
      'alerts': 'yes',
    });
    final response =
        await http.get(uri).timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      final map = decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
      final error = map['error'];
      final message = error is Map ? error['message']?.toString() : null;
      throw Exception(
        message?.trim().isNotEmpty == true
            ? message
            : 'WeatherAPI request failed (${response.statusCode})',
      );
    }
    if (decoded is! Map) {
      throw const FormatException('WeatherAPI returned an invalid response');
    }

    final placeLabel = await LocationService.placeLabelFromCoordinateString(
      LocationService.formatCoordinatesForStorage(
        position.latitude,
        position.longitude,
      ),
    );

    return parseWeatherApiResponse(
      Map<String, dynamic>.from(decoded),
      requestLatitude: position.latitude,
      requestLongitude: position.longitude,
      locationLabelOverride: placeLabel.isEmpty ? null : placeLabel,
    );
  }

  @visibleForTesting
  static DashboardWeather parseWeatherApiResponse(
    Map<String, dynamic> json, {
    DateTime? now,
    double? requestLatitude,
    double? requestLongitude,
    String? locationLabelOverride,
  }) {
    final location = _map(json['location']);
    final current = _map(json['current']);
    final condition = _map(current['condition']);
    if (current.isEmpty || condition.isEmpty) {
      throw const FormatException('WeatherAPI response is missing current data');
    }

    final code = _int(condition['code']);
    final daysRaw = _map(json['forecast'])['forecastday'];
    final dayMaps = daysRaw is List
        ? daysRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e))
        : const Iterable<Map<String, dynamic>>.empty();
    final daily = <WeatherDailyPoint>[];
    final allHours = <Map<String, dynamic>>[];

    for (final entry in dayMaps) {
      final date = _dateFromEpochOrText(entry['date_epoch'], entry['date']);
      final day = _map(entry['day']);
      final dayCondition = _map(day['condition']);
      final astro = _map(entry['astro']);
      final dayCode = _int(dayCondition['code']);
      if (date != null) {
        daily.add(
          WeatherDailyPoint(
            date: date,
            highC: _double(day['maxtemp_c']),
            lowC: _double(day['mintemp_c']),
            averageC: _nullableDouble(day['avgtemp_c']),
            maxWindKmh: _nullableDouble(day['maxwind_kph']),
            averageHumidity: _nullableInt(day['avghumidity']),
            totalPrecipitationMm: _nullableDouble(day['totalprecip_mm']),
            kind: DashboardWeather.kindFromWeatherApiCode(dayCode),
            weatherCode: dayCode,
            conditionText: _text(dayCondition['text']),
            precipitationChance: _nullableInt(day['daily_chance_of_rain']),
            sunrise: _text(astro['sunrise']),
            sunset: _text(astro['sunset']),
          ),
        );
      }
      final hours = entry['hour'];
      if (hours is List) {
        allHours.addAll(
          hours.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      }
    }

    // Prefer the location's local clock for hourly filtering so forecasts stay
    // aligned with the place being queried (not a mismatched device TZ).
    final referenceNow = now ??
        _dateFromEpochOrText(
          location['localtime_epoch'],
          location['localtime'],
        ) ??
        DateTime.now();
    final hourly = <WeatherHourlyPoint>[];
    for (final hour in allHours) {
      final time = _dateFromEpochOrText(hour['time_epoch'], hour['time']);
      if (time == null ||
          time.isBefore(referenceNow.subtract(const Duration(minutes: 30)))) {
        continue;
      }
      final hourCondition = _map(hour['condition']);
      final hourCode = _int(hourCondition['code']);
      hourly.add(
        WeatherHourlyPoint(
          time: time,
          temperatureC: _double(hour['temp_c']),
          feelsLikeC: _nullableDouble(hour['feelslike_c']),
          humidity: _nullableInt(hour['humidity']),
          windSpeedKmh: _nullableDouble(hour['wind_kph']),
          kind: DashboardWeather.kindFromWeatherApiCode(hourCode),
          weatherCode: hourCode,
          conditionText: _text(hourCondition['text']),
          precipitationChance: _nullableInt(hour['chance_of_rain']),
          isDay: _int(hour['is_day'], fallback: 1) == 1,
        ),
      );
      if (hourly.length >= 24) break;
    }

    final alertsRaw = _map(json['alerts'])['alert'];
    final alerts = <WeatherAlert>[];
    if (alertsRaw is List) {
      for (final raw in alertsRaw.whereType<Map>()) {
        final alert = Map<String, dynamic>.from(raw);
        final headline = _text(alert['headline']);
        if (headline.isEmpty) continue;
        alerts.add(
          WeatherAlert(
            headline: headline,
            event: _textOrNull(alert['event']),
            severity: _textOrNull(alert['severity']),
            urgency: _textOrNull(alert['urgency']),
            areas: _textOrNull(alert['areas']),
            effective: DateTime.tryParse(_text(alert['effective'])),
            expires: DateTime.tryParse(_text(alert['expires'])),
            description: _textOrNull(alert['desc']),
            instruction: _textOrNull(alert['instruction']),
          ),
        );
      }
    }

    final today = daily.isNotEmpty ? daily.first : null;
    final locationLabel = _resolveLocationLabel(
      location: location,
      requestLatitude: requestLatitude,
      requestLongitude: requestLongitude,
      locationLabelOverride: locationLabelOverride,
    );
    return DashboardWeather(
      temperatureC: _double(current['temp_c']),
      feelsLikeC: _nullableDouble(current['feelslike_c']),
      kind: DashboardWeather.kindFromWeatherApiCode(code),
      locationLabel: locationLabel,
      weatherCode: code,
      conditionText: _text(condition['text']),
      dataSourceLabel: 'WeatherAPI.com',
      humidity: _nullableInt(current['humidity']),
      highC: today?.highC,
      lowC: today?.lowC,
      isDay: _int(current['is_day'], fallback: 1) == 1,
      windSpeedKmh: _nullableDouble(current['wind_kph']),
      windDirection: _textOrNull(current['wind_dir']),
      windGustKmh: _nullableDouble(current['gust_kph']),
      pressureMb: _nullableDouble(current['pressure_mb']),
      precipitationMm: _nullableDouble(current['precip_mm']),
      visibilityKm: _nullableDouble(current['vis_km']),
      cloudCover: _nullableInt(current['cloud']),
      uvIndex: _nullableDouble(current['uv']),
      lastUpdated: _dateFromEpochOrText(
        current['last_updated_epoch'],
        current['last_updated'],
      ),
      sunrise: today?.sunrise,
      sunset: today?.sunset,
      hourly: hourly,
      daily: daily,
      alerts: alerts,
    );
  }

  /// Prefer a fresh high-accuracy fix (same path as attendance). Only fall back
  /// to last-known when it is recent and accurate enough — stale fused caches
  /// were returning cities hundreds of km away.
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

      final fresh = await _locationService.fetchHighAccuracyPosition();
      if (fresh != null && _isUsableFix(fresh, maxAge: const Duration(minutes: 3))) {
        return fresh;
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          _isUsableFix(
            last,
            maxAge: const Duration(minutes: 10),
            maxAccuracyMeters: 800,
          )) {
        return last;
      }

      // Fresh fix may still be usable even if accuracy is poor.
      if (fresh != null && _isUsableFix(fresh, maxAge: const Duration(minutes: 5), maxAccuracyMeters: 5000)) {
        return fresh;
      }
      if (last != null &&
          _isUsableFix(
            last,
            maxAge: const Duration(minutes: 20),
            maxAccuracyMeters: 5000,
          )) {
        return last;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _isUsableFix(
    Position position, {
    required Duration maxAge,
    double maxAccuracyMeters = 1500,
  }) {
    final age = DateTime.now().difference(position.timestamp);
    if (age.isNegative) return true;
    if (age > maxAge) return false;
    // accuracy <= 0 means unknown on some platforms — allow it.
    if (position.accuracy > 0 && position.accuracy > maxAccuracyMeters) {
      return false;
    }
    if (position.latitude.abs() < 0.01 && position.longitude.abs() < 0.01) {
      // (0,0) / null-island style junk.
      return false;
    }
    return true;
  }

  static String _resolveLocationLabel({
    required Map<String, dynamic> location,
    double? requestLatitude,
    double? requestLongitude,
    String? locationLabelOverride,
  }) {
    final override = locationLabelOverride?.trim() ?? '';
    if (override.isNotEmpty) return override;

    final apiLat = _nullableDouble(location['lat']);
    final apiLon = _nullableDouble(location['lon']);
    if (requestLatitude != null &&
        requestLongitude != null &&
        apiLat != null &&
        apiLon != null) {
      final distanceKm = Geolocator.distanceBetween(
            requestLatitude,
            requestLongitude,
            apiLat,
            apiLon,
          ) /
          1000.0;
      // WeatherAPI often snaps the place name to a distant station city.
      if (distanceKm > 25) {
        return 'Near you';
      }
    }

    final apiLabel = _weatherApiLocationLabel(location);
    return apiLabel.isEmpty ? 'Your location' : apiLabel;
  }

  static Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  static String _text(dynamic raw) => raw?.toString().trim() ?? '';

  static String? _textOrNull(dynamic raw) {
    final value = _text(raw);
    return value.isEmpty ? null : value;
  }

  static int _int(dynamic raw, {int fallback = 0}) {
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static int? _nullableInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  static double _double(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static double? _nullableDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  static DateTime? _dateFromEpochOrText(dynamic epoch, dynamic text) {
    final seconds = _nullableInt(epoch);
    if (seconds != null && seconds > 0) {
      // Absolute unix instant → device local for comparisons within one payload.
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ).toLocal();
    }
    final parsed = DateTime.tryParse(_text(text));
    return parsed;
  }

  static String _weatherApiLocationLabel(Map<String, dynamic> location) {
    final name = _text(location['name']);
    final region = _text(location['region']);
    final country = _text(location['country']);
    if (name.isNotEmpty && region.isNotEmpty && name != region) {
      return '$name, $region';
    }
    if (name.isNotEmpty && country.isNotEmpty) return '$name, $country';
    return name.isNotEmpty ? name : region;
  }
}

final weatherServiceProvider = Provider<WeatherService>(
  (ref) => WeatherService(locationService: ref.watch(locationServiceProvider)),
);
