import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;

/// Weather service using the free Open-Meteo API (no API key required).
///
/// Provides real-time weather data, marine conditions, and severe weather
/// alerts including storm/cyclone warnings for fisherman safety.
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1';

  /// Fetch current weather + marine conditions for given coordinates.
  static Future<WeatherData> getWeatherAndMarine(double lat, double lon) async {
    // Current weather + hourly wind/wave data
    final weatherUrl = Uri.parse(
      '$_baseUrl/forecast?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,apparent_temperature,'
      'weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,'
      'pressure_msl'
      '&hourly=weather_code,wind_speed_10m,wind_gusts_10m'
      '&forecast_days=1'
      '&timezone=auto',
    );

    // Marine/wave data
    final marineUrl = Uri.parse(
      'https://marine-api.open-meteo.com/v1/marine?latitude=$lat&longitude=$lon'
      '&current=wave_height,wave_direction,wave_period,'
      'wind_wave_height,swell_wave_height'
      '&hourly=wave_height,wind_wave_height'
      '&forecast_days=1'
      '&timezone=auto',
    );

    final responses = await Future.wait([
      http.get(weatherUrl),
      http.get(marineUrl).catchError((_) => http.Response('{}', 200)),
    ]);

    final weatherJson = jsonDecode(responses[0].body) as Map<String, dynamic>;
    Map<String, dynamic>? marineJson;
    try {
      final parsed = jsonDecode(responses[1].body) as Map<String, dynamic>;
      if (parsed.containsKey('current')) {
        marineJson = parsed;
      }
    } catch (_) {}

    return WeatherData.fromJson(weatherJson, marineJson);
  }
}

/// Parsed weather and marine data with storm/cyclone analysis.
class WeatherData {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final double windGusts;
  final int windDirection;
  final double pressure;
  final int weatherCode;

  // Marine data (may be null if location is inland)
  final double? waveHeight;
  final int? waveDirection;
  final double? wavePeriod;
  final double? swellHeight;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.windGusts,
    required this.windDirection,
    required this.pressure,
    required this.weatherCode,
    this.waveHeight,
    this.waveDirection,
    this.wavePeriod,
    this.swellHeight,
  });

  factory WeatherData.fromJson(
    Map<String, dynamic> weather,
    Map<String, dynamic>? marine,
  ) {
    final current = weather['current'] ?? {};
    final marineCurrent = marine?['current'];

    return WeatherData(
      temperature: (current['temperature_2m'] ?? 0).toDouble(),
      feelsLike: (current['apparent_temperature'] ?? 0).toDouble(),
      humidity: (current['relative_humidity_2m'] ?? 0).toInt(),
      windSpeed: (current['wind_speed_10m'] ?? 0).toDouble(),
      windGusts: (current['wind_gusts_10m'] ?? 0).toDouble(),
      windDirection: (current['wind_direction_10m'] ?? 0).toInt(),
      pressure: (current['pressure_msl'] ?? 1013).toDouble(),
      weatherCode: (current['weather_code'] ?? 0).toInt(),
      waveHeight: marineCurrent?['wave_height']?.toDouble(),
      waveDirection: marineCurrent?['wave_direction']?.toInt(),
      wavePeriod: marineCurrent?['wave_period']?.toDouble(),
      swellHeight: marineCurrent?['swell_wave_height']?.toDouble(),
    );
  }

  /// Human-readable weather description from WMO code
  String get weatherDescription {
    switch (weatherCode) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing drizzle';
      case 61:
        return 'Light rain';
      case 63:
        return 'Moderate rain';
      case 65:
        return 'Heavy rain';
      case 66:
      case 67:
        return 'Freezing rain';
      case 71:
        return 'Light snow';
      case 73:
        return 'Moderate snow';
      case 75:
        return 'Heavy snow';
      case 77:
        return 'Snow grains';
      case 80:
        return 'Light showers';
      case 81:
        return 'Moderate showers';
      case 82:
        return 'Violent showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
        return '⚡ Thunderstorm';
      case 96:
      case 99:
        return '⚡ Thunderstorm with hail';
      default:
        return 'Unknown';
    }
  }

  /// Weather icon from WMO code
  String get weatherIcon {
    if (weatherCode == 0 || weatherCode == 1) return '☀️';
    if (weatherCode == 2) return '⛅';
    if (weatherCode == 3) return '☁️';
    if (weatherCode == 45 || weatherCode == 48) return '🌫️';
    if (weatherCode >= 51 && weatherCode <= 57) return '🌦️';
    if (weatherCode >= 61 && weatherCode <= 67) return '🌧️';
    if (weatherCode >= 71 && weatherCode <= 77) return '🌨️';
    if (weatherCode >= 80 && weatherCode <= 82) return '🌧️';
    if (weatherCode >= 85 && weatherCode <= 86) return '🌨️';
    if (weatherCode >= 95) return '⛈️';
    return '🌤️';
  }

  /// Wind direction as compass text
  String get windDirectionText {
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    return directions[((windDirection + 11.25) / 22.5).floor() % 16];
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// STORM / CYCLONE ALERT SYSTEM
  /// Based on India Meteorological Department (IMD) criteria:
  /// - Cyclone: Wind speed > 62 km/h
  /// - Severe Cyclone: Wind speed > 88 km/h
  /// - Very Severe: Wind speed > 117 km/h
  /// - Storm surge: Pressure drop < 1000 hPa
  /// ═══════════════════════════════════════════════════════════════════════

  StormAlert? get stormAlert {
    // Check for cyclone-level winds (IMD classification)
    if (windSpeed >= 117 || windGusts >= 140) {
      return StormAlert(
        level: AlertLevel.extreme,
        title: '🌀 VERY SEVERE CYCLONIC STORM',
        message:
            'Wind ${windSpeed.toStringAsFixed(0)} km/h, Gusts ${windGusts.toStringAsFixed(0)} km/h. '
            'EXTREME DANGER — Return to shore immediately!',
      );
    }
    if (windSpeed >= 88 || windGusts >= 110) {
      return StormAlert(
        level: AlertLevel.severe,
        title: '🌀 SEVERE CYCLONIC STORM',
        message:
            'Wind ${windSpeed.toStringAsFixed(0)} km/h, Gusts ${windGusts.toStringAsFixed(0)} km/h. '
            'HIGH DANGER — Return to port immediately!',
      );
    }
    if (windSpeed >= 62 || windGusts >= 80) {
      return StormAlert(
        level: AlertLevel.warning,
        title: '⚠️ CYCLONIC STORM WARNING',
        message:
            'Wind ${windSpeed.toStringAsFixed(0)} km/h, Gusts ${windGusts.toStringAsFixed(0)} km/h. '
            'Sea conditions dangerous. Avoid deep sea voyage.',
      );
    }

    // Check for low pressure (depression / deep depression)
    if (pressure < 996) {
      return StormAlert(
        level: AlertLevel.warning,
        title: '⚠️ LOW PRESSURE SYSTEM',
        message:
            'Pressure ${pressure.toStringAsFixed(0)} hPa. '
            'Possible cyclone formation. Monitor conditions closely.',
      );
    }

    // Check for high waves
    if (waveHeight != null && waveHeight! > 4.0) {
      return StormAlert(
        level: AlertLevel.warning,
        title: '🌊 HIGH WAVE WARNING',
        message:
            'Wave height ${waveHeight!.toStringAsFixed(1)}m. '
            'Rough sea — small vessels should stay in port.',
      );
    }

    // Check thunderstorm
    if (weatherCode >= 95) {
      return StormAlert(
        level: AlertLevel.caution,
        title: '⛈️ THUNDERSTORM ALERT',
        message:
            'Thunderstorm activity detected. '
            'Lightning risk — avoid being on open water.',
      );
    }

    // Moderate wind advisory
    if (windSpeed >= 40) {
      return StormAlert(
        level: AlertLevel.caution,
        title: '💨 WIND ADVISORY',
        message:
            'Strong wind ${windSpeed.toStringAsFixed(0)} km/h. '
            'Small craft should exercise caution.',
      );
    }

    // High swell
    if (swellHeight != null && swellHeight! > 2.5) {
      return StormAlert(
        level: AlertLevel.caution,
        title: '🌊 SWELL ADVISORY',
        message:
            'Swell height ${swellHeight!.toStringAsFixed(1)}m. '
            'Moderate to rough seas expected.',
      );
    }

    return null; // No alert
  }

  /// Sea condition for fishermen
  String get seaCondition {
    if (waveHeight == null) return 'Data unavailable';
    if (waveHeight! < 0.5) return 'Calm 🟢';
    if (waveHeight! < 1.25) return 'Slight 🟢';
    if (waveHeight! < 2.5) return 'Moderate 🟡';
    if (waveHeight! < 4.0) return 'Rough 🟠';
    if (waveHeight! < 6.0) return 'Very Rough 🔴';
    return 'High / Phenomenal 🔴';
  }
}

enum AlertLevel { caution, warning, severe, extreme }

class StormAlert {
  final AlertLevel level;
  final String title;
  final String message;

  StormAlert({required this.level, required this.title, required this.message});

  Color get color {
    switch (level) {
      case AlertLevel.caution:
        return const Color(0xFFFFAB00);
      case AlertLevel.warning:
        return const Color(0xFFFF6D00);
      case AlertLevel.severe:
        return const Color(0xFFFF1744);
      case AlertLevel.extreme:
        return const Color(0xFFD50000);
    }
  }
}
