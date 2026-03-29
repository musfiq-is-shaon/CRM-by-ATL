import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<void> init() async {
    // Set Android platform settings
    await Geolocator.requestPermission();
  }

  Future<String?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null; // Handle dialog in UI
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      } else if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Return as "lat,lng" format
      return '${position.latitude},${position.longitude}';
    } catch (e) {
      print('Location error: $e');
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);
