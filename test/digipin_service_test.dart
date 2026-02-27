import 'package:flutter_test/flutter_test.dart';
import 'package:resqpin/services/digipin_service.dart';

void main() {
  group('DigipinService', () {
    group('encode', () {
      test('encodes New Delhi coordinates', () {
        // New Delhi: 28.6139, 77.2090
        final digipin = DigipinService.encode(28.6139, 77.2090);
        expect(digipin.length, 12); // 10 chars + 2 dashes
        expect(digipin[3], '-');
        expect(digipin[7], '-');
        // Only valid DIGIPIN characters
        final pin = digipin.replaceAll('-', '');
        expect(pin.length, 10);
        for (final c in pin.split('')) {
          expect(
            'FC98J327K456LMPT'.contains(c),
            isTrue,
            reason: 'Character $c must be in DIGIPIN grid',
          );
        }
      });

      test('encodes Mumbai coordinates', () {
        // Mumbai: 19.0760, 72.8777
        final digipin = DigipinService.encode(19.0760, 72.8777);
        expect(digipin.replaceAll('-', '').length, 10);
      });

      test('encodes Chennai coordinates', () {
        // Chennai: 13.0827, 80.2707
        final digipin = DigipinService.encode(13.0827, 80.2707);
        expect(digipin.replaceAll('-', '').length, 10);
      });

      test('encodes Kolkata coordinates', () {
        // Kolkata: 22.5726, 88.3639
        final digipin = DigipinService.encode(22.5726, 88.3639);
        expect(digipin.replaceAll('-', '').length, 10);
      });

      test('encodes boundary min coordinates', () {
        final digipin = DigipinService.encode(2.5, 63.5);
        expect(digipin.replaceAll('-', '').length, 10);
      });

      test('throws for latitude out of range', () {
        expect(
          () => DigipinService.encode(0.0, 77.0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws for longitude out of range', () {
        expect(
          () => DigipinService.encode(28.0, 40.0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws for latitude above max', () {
        expect(
          () => DigipinService.encode(39.0, 77.0),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('decode', () {
      test('decodes a valid DIGIPIN with dashes', () {
        // First encode a known point, then decode it back
        final encoded = DigipinService.encode(28.6139, 77.2090);
        final decoded = DigipinService.decode(encoded);
        // Should be close to original (within the resolution of the grid)
        expect(decoded.latitude, closeTo(28.6139, 0.01));
        expect(decoded.longitude, closeTo(77.2090, 0.01));
      });

      test('decodes a valid DIGIPIN without dashes', () {
        final encoded = DigipinService.encode(19.0760, 72.8777);
        final noDashes = encoded.replaceAll('-', '');
        final decoded = DigipinService.decode(noDashes);
        expect(decoded.latitude, closeTo(19.0760, 0.01));
        expect(decoded.longitude, closeTo(72.8777, 0.01));
      });

      test('throws for invalid DIGIPIN length', () {
        expect(
          () => DigipinService.decode('ABC'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws for invalid characters in DIGIPIN', () {
        expect(
          () => DigipinService.decode('ABCDEFGHIJ'), // 'A' not in grid
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('round-trip', () {
      test('encode then decode returns coordinates within precision', () {
        // Test multiple cities
        final testCases = [
          [28.6139, 77.2090], // Delhi
          [19.0760, 72.8777], // Mumbai
          [13.0827, 80.2707], // Chennai
          [22.5726, 88.3639], // Kolkata
          [12.9716, 77.5946], // Bangalore
          [17.3850, 78.4867], // Hyderabad
          [26.9124, 75.7873], // Jaipur
          [23.2599, 77.4126], // Bhopal
        ];

        for (final tc in testCases) {
          final lat = tc[0];
          final lon = tc[1];
          final encoded = DigipinService.encode(lat, lon);
          final decoded = DigipinService.decode(encoded);

          // 10-level grid gives ~0.001 degree precision
          expect(
            decoded.latitude,
            closeTo(lat, 0.005),
            reason: 'Latitude round-trip failed for ($lat, $lon)',
          );
          expect(
            decoded.longitude,
            closeTo(lon, 0.005),
            reason: 'Longitude round-trip failed for ($lat, $lon)',
          );
        }
      });

      test('generateDigipin returns same as encode for valid coordinates', () {
        final digipin = DigipinService.generateDigipin(28.6139, 77.2090);
        final encoded = DigipinService.encode(28.6139, 77.2090);
        expect(digipin, encoded);
      });

      test('generateDigipin returns OUT-OF-BOUNDS for invalid coordinates', () {
        final result = DigipinService.generateDigipin(0.0, 0.0);
        expect(result, 'OUT-OF-BOUNDS');
      });
    });

    group('format', () {
      test('DIGIPIN format is XXX-XXX-XXXX', () {
        final digipin = DigipinService.encode(22.0, 80.0);
        final parts = digipin.split('-');
        expect(parts.length, 3);
        expect(parts[0].length, 3);
        expect(parts[1].length, 3);
        expect(parts[2].length, 4);
      });
    });
  });
}
