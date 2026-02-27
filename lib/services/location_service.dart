import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;

  /// Check and request location permissions
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current position
  Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Start periodic location updates (every 10 seconds for officers)
  void startLocationUpdates({
    required Function(Position) onLocationChanged,
    int intervalSeconds = 10,
  }) {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // minimum 5 meters before update
        timeLimit: Duration(seconds: intervalSeconds),
      ),
    ).listen(onLocationChanged);
  }

  /// Stop location updates
  void stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Calculate distance between two points using Haversine (returns meters)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Estimate ETA (assuming average speed of 40 km/h in urban areas)
  static String estimateETA(double distanceMeters) {
    const averageSpeedMps = 40 * 1000 / 3600; // 40 km/h in m/s
    final seconds = distanceMeters / averageSpeedMps;
    final minutes = (seconds / 60).ceil();
    if (minutes < 1) return '< 1 min';
    if (minutes == 1) return '1 min';
    return '$minutes mins';
  }

  void dispose() {
    stopLocationUpdates();
  }
}
