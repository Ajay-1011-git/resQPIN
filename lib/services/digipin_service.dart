/// Official DIGIPIN Encoder and Decoder
///
/// Faithfully translated from the official IndiaPost DIGIPIN repository:
/// https://github.com/INDIAPOST-gov/digipin
///
/// DIGIPIN (Digital PIN) is a 10-character alphanumeric geocode developed
/// by the Department of Posts, India, in collaboration with IIT Hyderabad
/// and NRSC, ISRO.
///
/// This implementation replicates the official JavaScript algorithm 1:1.
library;

/// Data class for decoded DIGIPIN coordinates
class DigipinCoordinates {
  final double latitude;
  final double longitude;

  const DigipinCoordinates({required this.latitude, required this.longitude});

  @override
  String toString() =>
      'DigipinCoordinates(lat: ${latitude.toStringAsFixed(6)}, '
      'lon: ${longitude.toStringAsFixed(6)})';
}

class DigipinService {
  // ─── Official 4×4 DIGIPIN Grid ─────────────────────────────────────────────
  // Exactly as defined in the official repo:
  // https://github.com/INDIAPOST-gov/digipin/blob/main/src/digipin.js
  static const List<List<String>> _digipinGrid = [
    ['F', 'C', '9', '8'],
    ['J', '3', '2', '7'],
    ['K', '4', '5', '6'],
    ['L', 'M', 'P', 'T'],
  ];

  // ─── India Geographic Bounds ───────────────────────────────────────────────
  static const double _minLat = 2.5;
  static const double _maxLat = 38.5;
  static const double _minLon = 63.5;
  static const double _maxLon = 99.5;

  /// Encode latitude and longitude into an official DIGIPIN string.
  ///
  /// Returns a 10-character DIGIPIN formatted as `XXX-XXX-XXXX`.
  ///
  /// Throws [ArgumentError] if coordinates are outside India's bounds.
  ///
  /// Example:
  /// ```dart
  /// final digipin = DigipinService.encode(28.6139, 77.2090);
  /// // Returns something like "383-2M4-593P"
  /// ```
  static String encode(double lat, double lon) {
    if (lat < _minLat || lat > _maxLat) {
      throw ArgumentError(
        'Latitude out of range ($lat). '
        'Must be between $_minLat and $_maxLat',
      );
    }
    if (lon < _minLon || lon > _maxLon) {
      throw ArgumentError(
        'Longitude out of range ($lon). '
        'Must be between $_minLon and $_maxLon',
      );
    }

    double minLat = _minLat;
    double maxLat = _maxLat;
    double minLon = _minLon;
    double maxLon = _maxLon;

    final buffer = StringBuffer();

    for (int level = 1; level <= 10; level++) {
      final latDiv = (maxLat - minLat) / 4;
      final lonDiv = (maxLon - minLon) / 4;

      // REVERSED row logic — matches official implementation exactly
      int row = 3 - ((lat - minLat) / latDiv).floor();
      int col = ((lon - minLon) / lonDiv).floor();

      // Clamp to valid range [0, 3]
      row = row.clamp(0, 3);
      col = col.clamp(0, 3);

      buffer.write(_digipinGrid[row][col]);

      // Add dashes after 3rd and 6th characters
      if (level == 3 || level == 6) buffer.write('-');

      // Update bounds — reverse logic for row (matches official)
      final newMaxLat = minLat + latDiv * (4 - row);
      final newMinLat = minLat + latDiv * (3 - row);

      final newMinLon = minLon + lonDiv * col;
      final newMaxLon = newMinLon + lonDiv;

      maxLat = newMaxLat;
      minLat = newMinLat;
      minLon = newMinLon;
      maxLon = newMaxLon;
    }

    return buffer.toString();
  }

  /// Decode a DIGIPIN string back to its center latitude and longitude.
  ///
  /// Accepts DIGIPIN with or without dashes.
  ///
  /// Throws [ArgumentError] if the DIGIPIN is invalid.
  ///
  /// Example:
  /// ```dart
  /// final coords = DigipinService.decode("383-2M4-593P");
  /// print(coords.latitude);  // ~28.6139
  /// print(coords.longitude); // ~77.2090
  /// ```
  static DigipinCoordinates decode(String digipin) {
    // Remove dashes and convert to uppercase
    final pin = digipin.replaceAll('-', '').toUpperCase();

    if (pin.length != 10) {
      throw ArgumentError(
        'Invalid DIGIPIN: must be 10 characters (got ${pin.length})',
      );
    }

    double minLat = _minLat;
    double maxLat = _maxLat;
    double minLon = _minLon;
    double maxLon = _maxLon;

    for (int i = 0; i < 10; i++) {
      final char = pin[i];

      // Locate character in DIGIPIN grid
      int ri = -1, ci = -1;
      bool found = false;

      for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 4; c++) {
          if (_digipinGrid[r][c] == char) {
            ri = r;
            ci = c;
            found = true;
            break;
          }
        }
        if (found) break;
      }

      if (!found) {
        throw ArgumentError(
          "Invalid character '$char' at position $i in DIGIPIN",
        );
      }

      final latDiv = (maxLat - minLat) / 4;
      final lonDiv = (maxLon - minLon) / 4;

      final lat1 = maxLat - latDiv * (ri + 1);
      final lat2 = maxLat - latDiv * ri;
      final lon1 = minLon + lonDiv * ci;
      final lon2 = minLon + lonDiv * (ci + 1);

      // Update bounding box for next level
      minLat = lat1;
      maxLat = lat2;
      minLon = lon1;
      maxLon = lon2;
    }

    // Return center of final grid cell
    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;

    return DigipinCoordinates(latitude: centerLat, longitude: centerLon);
  }

  // ─── Convenience wrapper matching the old API ──────────────────────────────

  /// Generate DIGIPIN from lat/lon (convenience alias for [encode]).
  static String generateDigipin(double lat, double lon) {
    try {
      return encode(lat, lon);
    } catch (_) {
      // Fallback for coordinates outside India's bounds
      // (e.g., during testing or emulator use)
      return 'OUT-OF-BOUNDS';
    }
  }
}
