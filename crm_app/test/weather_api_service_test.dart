import 'package:flutter_test/flutter_test.dart';

import 'package:crm/core/services/weather_service.dart';
import 'package:crm/data/models/weather_model.dart';

void main() {
  group('WeatherAPI parsing', () {
    final payload = <String, dynamic>{
      'location': {
        'name': 'Dhaka',
        'region': 'Dhaka',
        'country': 'Bangladesh',
        'localtime_epoch': 1784628000,
      },
      'current': {
        'last_updated_epoch': 1784627700,
        'temp_c': 31.2,
        'is_day': 1,
        'condition': {'text': 'Partly cloudy', 'code': 1003},
        'wind_kph': 14.8,
        'wind_dir': 'SSE',
        'pressure_mb': 1002.0,
        'precip_mm': 0.2,
        'humidity': 76,
        'cloud': 48,
        'feelslike_c': 37.1,
        'vis_km': 8.0,
        'uv': 7.0,
        'gust_kph': 25.6,
      },
      'forecast': {
        'forecastday': [
          {
            'date': '2026-07-21',
            'date_epoch': 1784592000,
            'day': {
              'maxtemp_c': 33.0,
              'mintemp_c': 27.0,
              'avgtemp_c': 30.0,
              'maxwind_kph': 22.0,
              'totalprecip_mm': 4.5,
              'avghumidity': 78,
              'daily_chance_of_rain': 70,
              'condition': {'text': 'Moderate rain', 'code': 1189},
            },
            'astro': {'sunrise': '05:23 AM', 'sunset': '06:47 PM'},
            'hour': [
              {
                'time': '2026-07-21 16:00',
                'time_epoch': 1784620800,
                'temp_c': 31.0,
                'feelslike_c': 36.0,
                'humidity': 77,
                'wind_kph': 15.0,
                'is_day': 1,
                'chance_of_rain': 65,
                'condition': {'text': 'Patchy rain nearby', 'code': 1063},
              },
              {
                'time': '2026-07-21 17:00',
                'time_epoch': 1784624400,
                'temp_c': 30.5,
                'feelslike_c': 35.0,
                'humidity': 80,
                'wind_kph': 13.0,
                'is_day': 1,
                'chance_of_rain': 75,
                'condition': {'text': 'Rain', 'code': 1183},
              },
            ],
          },
        ],
      },
      'alerts': {
        'alert': [
          {
            'headline': 'Heavy rain possible',
            'event': 'Rain advisory',
            'severity': 'Moderate',
            'urgency': 'Expected',
            'areas': 'Dhaka',
            'effective': '2026-07-21T10:00:00+06:00',
            'expires': '2026-07-21T20:00:00+06:00',
            'desc': 'Localized flooding is possible.',
            'instruction': 'Avoid flooded roads.',
          },
        ],
      },
    };

    test('maps current conditions, location and source', () {
      final weather = WeatherService.parseWeatherApiResponse(
        payload,
        now: DateTime.fromMillisecondsSinceEpoch(1784620000 * 1000),
      );

      expect(weather.locationLabel, 'Dhaka, Bangladesh');
      expect(weather.temperatureC, 31.2);
      expect(weather.feelsLikeC, 37.1);
      expect(weather.kind, DashboardWeatherKind.partlyCloudy);
      expect(weather.dataSourceLabel, 'WeatherAPI.com');
      expect(weather.windDirection, 'SSE');
      expect(weather.uvIndex, 7.0);
      expect(weather.uvLabel, 'High');
    });

    test('prefers reverse-geocoded location label override', () {
      final weather = WeatherService.parseWeatherApiResponse(
        payload,
        now: DateTime.fromMillisecondsSinceEpoch(1784620000 * 1000),
        locationLabelOverride: 'Mirpur, Dhaka',
      );
      expect(weather.locationLabel, 'Mirpur, Dhaka');
    });

    test('avoids distant WeatherAPI station city names', () {
      final distant = Map<String, dynamic>.from(payload);
      distant['location'] = {
        'name': 'Chittagong',
        'region': 'Chittagong',
        'country': 'Bangladesh',
        'lat': 22.35,
        'lon': 91.8,
        'localtime_epoch': 1784628000,
      };
      final weather = WeatherService.parseWeatherApiResponse(
        distant,
        now: DateTime.fromMillisecondsSinceEpoch(1784620000 * 1000),
        requestLatitude: 23.81,
        requestLongitude: 90.41,
      );
      expect(weather.locationLabel, 'Near you');
    });

    test('maps hourly, daily, astronomy and alerts', () {
      final weather = WeatherService.parseWeatherApiResponse(
        payload,
        now: DateTime.fromMillisecondsSinceEpoch(1784620000 * 1000),
      );

      expect(weather.hourly, isNotEmpty);
      expect(weather.hourly.first.precipitationChance, 65);
      expect(weather.hourly.first.kind, DashboardWeatherKind.rainy);
      expect(weather.daily, hasLength(1));
      expect(weather.daily.first.highC, 33);
      expect(weather.daily.first.sunrise, '05:23 AM');
      expect(weather.sunset, '06:47 PM');
      expect(weather.alerts.single.event, 'Rain advisory');
      expect(weather.smartSummary, 'Heavy rain possible');
    });

    test('maps WeatherAPI condition families', () {
      expect(
        DashboardWeather.kindFromWeatherApiCode(1000),
        DashboardWeatherKind.sunny,
      );
      expect(
        DashboardWeather.kindFromWeatherApiCode(1135),
        DashboardWeatherKind.foggy,
      );
      expect(
        DashboardWeather.kindFromWeatherApiCode(1219),
        DashboardWeatherKind.snowy,
      );
      expect(
        DashboardWeather.kindFromWeatherApiCode(1276),
        DashboardWeatherKind.stormy,
      );
    });
  });
}
