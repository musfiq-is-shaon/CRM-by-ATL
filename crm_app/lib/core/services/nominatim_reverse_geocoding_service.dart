import 'dart:async';

import 'package:dio/dio.dart';

/// Reverse geocode via [OpenStreetMap Nominatim](https://nominatim.org/release-docs/develop/api/Reverse/).
///
/// Public instance is free; follow [usage policy](https://operations.osmfoundation.org/policies/nominatim/)
/// (identifiable User-Agent, max ~1 request/second — enforced here with a simple queue).
class NominatimReverseGeocodingService {
  NominatimReverseGeocodingService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      validateStatus: (s) => s != null && s < 500,
      headers: const {
        // Required by OSM: identify the application (do not use a generic bot UA).
        'User-Agent': 'CRM-Mobile/1.0 (Flutter; employee attendance check-in/out)',
      },
    ),
  );

  static const _reverseUrl =
      'https://nominatim.openstreetmap.org/reverse';

  static Completer<void>? _busy;
  static DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<T> _serial<T>(Future<T> Function() fn) async {
    while (_busy != null) {
      await _busy!.future;
    }
    _busy = Completer<void>();
    try {
      final elapsed = DateTime.now().difference(_lastRequestAt);
      if (elapsed < const Duration(seconds: 1)) {
        await Future<void>.delayed(const Duration(seconds: 1) - elapsed);
      }
      _lastRequestAt = DateTime.now();
      return await fn();
    } finally {
      _busy!.complete();
      _busy = null;
    }
  }

  /// Street / neighbourhood / city (no country). Null on failure.
  static Future<String?> placeLabelFromCoordinates(
    double lat,
    double lng, {
    String? languageCode,
  }) async {
    return _serial(() async {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          _reverseUrl,
          queryParameters: <String, dynamic>{
            'lat': lat,
            'lon': lng,
            'format': 'jsonv2',
            'addressdetails': 1,
            'zoom': 18,
          },
          options: Options(
            headers: {
              if (languageCode != null && languageCode.isNotEmpty)
                'Accept-Language': languageCode,
            },
          ),
        );

        final data = response.data;
        if (data == null) return null;
        if (data.containsKey('error')) return null;

        final addr = data['address'] as Map<String, dynamic>?;
        final built = _labelFromAddress(addr);
        if (built.isNotEmpty) return built;

        final display = data['display_name'] as String?;
        return _shortDisplayName(display);
      } on DioException {
        return null;
      } catch (_) {
        return null;
      }
    });
  }

  static String? _pick(Map<String, dynamic>? addr, List<String> keys) {
    if (addr == null) return null;
    for (final k in keys) {
      final v = addr[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static String _labelFromAddress(Map<String, dynamic>? addr) {
    final hn = _pick(addr, ['house_number', 'house_name']);
    final road = _pick(addr, [
      'road',
      'pedestrian',
      'footway',
      'path',
      'residential',
      'cycleway',
    ]);

    var roadLine = [
      if (hn != null && hn.isNotEmpty) hn,
      if (road != null &&
          road.isNotEmpty &&
          (hn == null || road.toLowerCase() != hn.toLowerCase()))
        road,
    ].join(' ').trim();

    if (roadLine.isEmpty && road != null) roadLine = road;

    final area = _pick(addr, [
      'neighbourhood',
      'suburb',
      'quarter',
      'city_district',
      'district',
      'hamlet',
    ]);

    final city = _pick(addr, [
      'city',
      'town',
      'village',
      'municipality',
      'county',
    ]);

    final parts = <String>[];
    void pushDistinct(String? s) {
      final t = s?.trim();
      if (t == null || t.isEmpty) return;
      final tl = t.toLowerCase();
      for (final existing in parts) {
        final el = existing.toLowerCase();
        if (el == tl) return;
        if (el.contains(tl) || tl.contains(el)) {
          if (t.length > existing.length) {
            parts[parts.indexOf(existing)] = t;
          }
          return;
        }
      }
      parts.add(t);
    }

    pushDistinct(roadLine.isNotEmpty ? roadLine : null);
    pushDistinct(area);
    pushDistinct(city);

    return parts.join(', ');
  }

  static String? _shortDisplayName(String? display) {
    if (display == null || display.trim().isEmpty) return null;
    final segs = display
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (segs.length >= 2) segs.removeLast();
    if (segs.isEmpty) return null;
    return segs.take(5).join(', ');
  }
}
