import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class IosUpdateInfo {
  const IosUpdateInfo({
    required this.currentVersion,
    required this.storeVersion,
    required this.storeUrl,
  });

  final String currentVersion;
  final String storeVersion;
  final Uri storeUrl;
}

/// Checks the public App Store listing for a newer iOS version.
///
/// Unlike Google Play, Apple has no native immediate-update API. The supported
/// equivalent is to block app use and send the user to the App Store.
class IosForceUpdateService {
  IosForceUpdateService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<IosUpdateInfo?> check() async {
    if (kIsWeb || !Platform.isIOS) return null;

    try {
      final package = await PackageInfo.fromPlatform();
      final lookupUri = Uri.https(
        'itunes.apple.com',
        '/lookup',
        {'bundleId': package.packageName},
      );
      final response = await _client
          .get(lookupUri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['results'] is! List) return null;
      final results = decoded['results'] as List;
      if (results.isEmpty || results.first is! Map) return null;

      final listing = Map<String, dynamic>.from(results.first as Map);
      final storeVersion = listing['version']?.toString().trim() ?? '';
      final trackId = listing['trackId']?.toString().trim() ?? '';
      final webUrl = listing['trackViewUrl']?.toString().trim() ?? '';
      if (storeVersion.isEmpty ||
          !_isNewer(storeVersion, package.version)) {
        return null;
      }

      final storeUrl = trackId.isNotEmpty
          ? Uri.parse('https://apps.apple.com/app/id$trackId')
          : Uri.tryParse(webUrl);
      if (storeUrl == null) return null;

      return IosUpdateInfo(
        currentVersion: package.version,
        storeVersion: storeVersion,
        storeUrl: storeUrl,
      );
    } catch (error, stackTrace) {
      debugPrint('App Store update check failed: $error\n$stackTrace');
      // A temporary lookup failure must not lock users out.
      return null;
    }
  }

  static bool _isNewer(String candidate, String current) {
    final candidateParts = _numericParts(candidate);
    final currentParts = _numericParts(current);
    final length = candidateParts.length > currentParts.length
        ? candidateParts.length
        : currentParts.length;
    for (var i = 0; i < length; i++) {
      final a = i < candidateParts.length ? candidateParts[i] : 0;
      final b = i < currentParts.length ? currentParts[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  static List<int> _numericParts(String version) {
    return version
        .split(RegExp(r'[.+-]'))
        .map((part) => int.tryParse(RegExp(r'\d+').stringMatch(part) ?? '') ?? 0)
        .toList();
  }
}
