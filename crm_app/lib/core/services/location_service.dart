import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'nominatim_reverse_geocoding_service.dart';

/// Coordinates for API + human-readable label for UI.
class CapturedLocation {
  CapturedLocation({
    required this.coordinatesString,
    required this.placeLabel,
  });

  /// Sent to backend, e.g. `23.818964364020204, 90.365199796851`.
  final String coordinatesString;

  /// Shown on dashboard (street / area); may be empty if geocode fails.
  final String placeLabel;
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static final RegExp _latLngPair = RegExp(
    r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
  );

  /// True if [s] looks like `"lat, lng"` (numbers only).
  static bool looksLikeCoordinatesString(String s) {
    return _latLngPair.hasMatch(s.trim());
  }

  /// Resolve stored coordinate string to a place name for display (never raw coords on success).
  static Future<String> placeLabelFromCoordinateString(String raw) async {
    final t = raw.trim();
    if (!looksLikeCoordinatesString(t)) return t;
    final m = _latLngPair.firstMatch(t);
    if (m == null) return _fallbackPlaceLabel;
    final lat = double.tryParse(m.group(1)!);
    final lng = double.tryParse(m.group(2)!);
    if (lat == null || lng == null) return _fallbackPlaceLabel;
    try {
      final lang = ui.PlatformDispatcher.instance.locale.languageCode;
      final osm = await NominatimReverseGeocodingService.placeLabelFromCoordinates(
        lat,
        lng,
        languageCode: lang,
      );
      if (osm != null && osm.isNotEmpty) return osm;

      await _syncGeocodingLocale();
      final marks = await placemarkFromCoordinates(
        lat,
        lng,
      ).timeout(const Duration(seconds: 12));
      if (marks.isEmpty) return _fallbackPlaceLabel;
      final label = _formatPlacemarkList(marks);
      return label.isNotEmpty ? label : _fallbackPlaceLabel;
    } on TimeoutException {
      return _fallbackPlaceLabel;
    } catch (_) {
      return _fallbackPlaceLabel;
    }
  }

  static const String _fallbackPlaceLabel = 'Location recorded';

  Future<void> init() async {
    await Geolocator.requestPermission();
  }

  Future<String?> getCurrentLocation() async {
    final captured = await getCurrentLocationForAttendance();
    return captured?.coordinatesString;
  }

  Future<CapturedLocation?> getCurrentLocationForAttendance() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      } else if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final lat = position.latitude;
      final lng = position.longitude;
      final coords = formatCoordinatesForStorage(lat, lng);
      final placeLabel = await _reverseGeocodeToLabel(lat, lng);

      return CapturedLocation(
        coordinatesString: coords,
        placeLabel: placeLabel,
      );
    } catch (e) {
      print('Location error: $e');
      return null;
    }
  }

  static Future<String> _reverseGeocodeToLabel(double lat, double lng) async {
    try {
      final lang = ui.PlatformDispatcher.instance.locale.languageCode;
      final osm = await NominatimReverseGeocodingService.placeLabelFromCoordinates(
        lat,
        lng,
        languageCode: lang,
      );
      if (osm != null && osm.isNotEmpty) return osm;

      await _syncGeocodingLocale();
      final marks = await placemarkFromCoordinates(
        lat,
        lng,
      ).timeout(const Duration(seconds: 15));
      if (marks.isEmpty) return '';
      return _formatPlacemarkList(marks);
    } on TimeoutException {
      return '';
    } catch (_) {
      return '';
    }
  }

  static String? _lastLocaleSynced;

  /// Android geocoder can return richer lines when locale matches the device.
  static Future<void> _syncGeocodingLocale() async {
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final country = locale.countryCode;
      final id = country != null && country.isNotEmpty
          ? '${locale.languageCode}_$country'
          : locale.languageCode;
      if (id == _lastLocaleSynced) return;
      await setLocaleIdentifier(id);
      _lastLocaleSynced = id;
    } catch (_) {}
  }

  /// Prefer the placemark with the most street-level detail (not just “city + country”).
  static int _placemarkDetailScore(Placemark p) {
    var score = 0;
    final st = _cleanPart(p.street);
    final th = _cleanPart(p.thoroughfare);
    final subT = _cleanPart(p.subThoroughfare);
    final subL = _cleanPart(p.subLocality);
    final nm = _cleanPart(p.name);
    final loc = _cleanPart(p.locality);

    if (st != null) score += 60 + st.length.clamp(0, 80);
    if (th != null) score += 45;
    if (subT != null) score += 25;
    if (subL != null) score += 40;
    if (nm != null) {
      if (loc == null || nm.toLowerCase() != loc.toLowerCase()) {
        score += 35;
      }
    }
    if (_cleanPart(p.subAdministrativeArea) != null) score += 8;
    if (loc != null) score += 5;
    return score;
  }

  static Placemark _pickBestPlacemark(List<Placemark> marks) {
    return marks.reduce(
      (a, b) => _placemarkDetailScore(b) > _placemarkDetailScore(a) ? b : a,
    );
  }

  /// Android/iOS may return several results; merge the richest street line and pick best anchor.
  static String _formatPlacemarkList(List<Placemark> marks) {
    final best = _pickBestPlacemark(marks);

    String? road = _roadLine(best);
    for (final p in marks) {
      final r = _roadLine(p);
      if (r == null) continue;
      if (road == null || r.length > road.length) road = r;
    }

    String? subLoc = _cleanPart(best.subLocality);
    if (subLoc == null || subLoc.isEmpty) {
      for (final p in marks) {
        final s = _cleanPart(p.subLocality);
        if (s != null && s.isNotEmpty) {
          subLoc = s;
          break;
        }
      }
    }

    String? city = _cleanPart(best.locality);
    if (city == null || city.isEmpty) {
      city = _cleanPart(best.subAdministrativeArea);
    }
    if (city == null || city.isEmpty) {
      for (final p in marks) {
        final c = _cleanPart(p.locality) ?? _cleanPart(p.subAdministrativeArea);
        if (c != null && c.isNotEmpty) {
          city = c;
          break;
        }
      }
    }

    String? name = _distinctName(best, city);
    if (name == null || name.isEmpty) {
      for (final p in marks) {
        final c = _cleanPart(p.locality) ?? _cleanPart(p.subAdministrativeArea);
        final n = _distinctName(p, city ?? c);
        if (n != null && n.isNotEmpty) {
          name = n;
          break;
        }
      }
    }

    return _composeDisplayLabel(
      road: road,
      featureName: name,
      subLocality: subLoc,
      city: city,
    );
  }

  static String? _roadLine(Placemark p) {
    final subT = _cleanPart(p.subThoroughfare);
    final th = _cleanPart(p.thoroughfare);
    if (subT != null || th != null) {
      return [?subT, ?th].join(' ').trim();
    }
    return _cleanPart(p.street);
  }

  /// [cityContext] is used to drop [name] when it only repeats the city.
  static String? _distinctName(Placemark p, String? cityContext) {
    final n = _cleanPart(p.name);
    if (n == null) return null;
    final nl = n.toLowerCase();
    final city = cityContext?.toLowerCase();
    if (city != null && nl == city) return null;
    final c = _cleanPart(p.country)?.toLowerCase();
    if (c != null && nl == c) return null;
    final adm = _cleanPart(p.administrativeArea)?.toLowerCase();
    if (adm != null && nl == adm) return null;
    if (RegExp(r'^\d{1,6}[A-Za-z]?$').hasMatch(n.trim())) return null;
    return n;
  }

  /// Street / neighbourhood first; **no country** (avoids “Dhaka, Bangladesh” only).
  static String _composeDisplayLabel({
    String? road,
    String? featureName,
    String? subLocality,
    String? city,
  }) {
    final out = <String>[];
    void push(String? s) {
      final t = _cleanPart(s);
      if (t == null) return;
      final tl = t.toLowerCase();
      for (final existing in out) {
        final el = existing.toLowerCase();
        if (el == tl) return;
        if (el.contains(tl) || tl.contains(el)) {
          if (t.length > existing.length) {
            out[out.indexOf(existing)] = t;
          }
          return;
        }
      }
      out.add(t);
    }

    push(road);
    push(featureName);
    push(subLocality);
    push(city);

    return out.join(', ');
  }

  static String? _cleanPart(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.isEmpty || t.toLowerCase() == 'null' || t == 'Unnamed') {
      return null;
    }
    return t;
  }

  static String formatCoordinatesForStorage(double lat, double lng) {
    return '${_plainDouble(lat)}, ${_plainDouble(lng)}';
  }

  static String _plainDouble(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    final s = v.toString();
    if (s.contains('e') || s.contains('E')) {
      return v.toStringAsFixed(15);
    }
    return s;
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);
