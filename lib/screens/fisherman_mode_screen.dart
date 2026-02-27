import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/sos_service.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../constants.dart';
import 'sos_tracking_screen.dart';
import 'sos_confirmation_dialog.dart';

class FishermanModeScreen extends StatefulWidget {
  final UserModel user;

  const FishermanModeScreen({super.key, required this.user});

  @override
  State<FishermanModeScreen> createState() => _FishermanModeScreenState();
}

class _FishermanModeScreenState extends State<FishermanModeScreen> {
  final SOSService _sosService = SOSService();
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  bool _weatherLoading = true;
  WeatherData? _weather;
  String? _weatherError;
  String _selectedSeverity = 'MEDIUM';
  Timer? _weatherTimer;

  final List<String> _subcategories = kSubcategories['FISHERMAN']!;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    // Auto-refresh weather every 5 minutes
    _weatherTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _fetchWeather(),
    );
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _weatherLoading = true;
      _weatherError = null;
    });
    try {
      final pos = await _locationService.getCurrentPosition();
      final data = await WeatherService.getWeatherAndMarine(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) {
        setState(() {
          _weather = data;
          _weatherLoading = false;
        });

        // Send notification if storm alert detected
        if (data.stormAlert != null) {
          NotificationService().showWeatherAlert(
            title: data.stormAlert!.title,
            body: data.stormAlert!.message,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherError = 'Weather unavailable: $e';
          _weatherLoading = false;
        });
      }
    }
  }

  Future<void> _sendFishermanSOS(String subCategory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          SOSConfirmationDialog(sosType: 'FISHERMAN', subCategory: subCategory),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final sos = await _sosService.createSOS(
        type: 'FISHERMAN',
        subCategory: subCategory,
        severity: _selectedSeverity,
        createdBy: widget.user.uid,
        createdByName: widget.user.name,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SOSTrackingScreen(sosId: sos.sosId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fisherman Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Weather',
            onPressed: _fetchWeather,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Storm/Cyclone Alert Banner ──────────────────
                  if (_weather?.stormAlert != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _weather!.stormAlert!.color.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _weather!.stormAlert!.color,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _weather!.stormAlert!.title,
                            style: TextStyle(
                              color: _weather!.stormAlert!.color,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _weather!.stormAlert!.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ─── Weather Dashboard ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00838F).withValues(alpha: 0.25),
                          const Color(0xFF006064).withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00838F).withValues(alpha: 0.4),
                      ),
                    ),
                    child: _weatherLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: Color(0xFF4DD0E1),
                              ),
                            ),
                          )
                        : _weatherError != null
                        ? Center(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.cloud_off,
                                  color: Colors.grey,
                                  size: 36,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _weatherError!,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Weather header
                              Row(
                                children: [
                                  Text(
                                    _weather!.weatherIcon,
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_weather!.temperature.toStringAsFixed(1)}°C',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          _weather!.weatherDescription,
                                          style: const TextStyle(
                                            color: Color(0xFF4DD0E1),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Feels ${_weather!.feelsLike.toStringAsFixed(0)}°C',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${_weather!.humidity}% humidity',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(
                                color: Color(0xFF00838F),
                                height: 1,
                              ),
                              const SizedBox(height: 14),

                              // Wind & Pressure row
                              Row(
                                children: [
                                  _WeatherTile(
                                    icon: Icons.air,
                                    label: 'Wind',
                                    value:
                                        '${_weather!.windSpeed.toStringAsFixed(0)} km/h ${_weather!.windDirectionText}',
                                  ),
                                  const SizedBox(width: 12),
                                  _WeatherTile(
                                    icon: Icons.speed,
                                    label: 'Gusts',
                                    value:
                                        '${_weather!.windGusts.toStringAsFixed(0)} km/h',
                                  ),
                                  const SizedBox(width: 12),
                                  _WeatherTile(
                                    icon: Icons.compress,
                                    label: 'Pressure',
                                    value:
                                        '${_weather!.pressure.toStringAsFixed(0)} hPa',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Marine conditions row
                              if (_weather!.waveHeight != null) ...[
                                Row(
                                  children: [
                                    _WeatherTile(
                                      icon: Icons.waves,
                                      label: 'Waves',
                                      value:
                                          '${_weather!.waveHeight!.toStringAsFixed(1)}m',
                                    ),
                                    const SizedBox(width: 12),
                                    _WeatherTile(
                                      icon: Icons.pool,
                                      label: 'Swell',
                                      value: _weather!.swellHeight != null
                                          ? '${_weather!.swellHeight!.toStringAsFixed(1)}m'
                                          : 'N/A',
                                    ),
                                    const SizedBox(width: 12),
                                    _WeatherTile(
                                      icon: Icons.sailing,
                                      label: 'Sea',
                                      value: _weather!.seaCondition,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),

                  // ─── Severity ──────────────────────────────────
                  Text(
                    'Severity',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: kSeverityLevels.map((level) {
                      final isSelected = level == _selectedSeverity;
                      final color = kSeverityColors[level]!;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedSeverity = level),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.2)
                                  : const Color(0xFF2A2A3C),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? color : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                level,
                                style: TextStyle(
                                  color: isSelected ? color : Colors.grey,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ─── Emergency Types ───────────────────────────
                  Text(
                    'Select Emergency Type',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(_subcategories.length, (i) {
                    final sub = _subcategories[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: const Color(0xFF2A2A3C),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _sendFishermanSOS(sub),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  color: Color(0xFF4DD0E1),
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    sub,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _WeatherTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF4DD0E1)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
