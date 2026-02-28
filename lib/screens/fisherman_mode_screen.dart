import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
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
  double? _lat;
  double? _lon;

  final List<String> _subcategories = kSubcategories['FISHERMAN']!;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
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
      _lat = pos.latitude;
      _lon = pos.longitude;
      final data = await WeatherService.getWeatherAndMarine(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) {
        setState(() {
          _weather = data;
          _weatherLoading = false;
        });
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
          AppTheme.fadeSlideRoute(SOSTrackingScreen(sosId: sos.sosId)),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Fisherman Mode',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Weather',
            onPressed: _fetchWeather,
          ),
        ],
      ),
      body: LiquidBackground(
        accentColor: AppTheme.fishermanColor,
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ─── Storm/Cyclone Alert Banner ──────────────
                      if (_weather?.stormAlert != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _weather!.stormAlert!.color.withValues(
                                  alpha: 0.25,
                                ),
                                _weather!.stormAlert!.color.withValues(
                                  alpha: 0.08,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _weather!.stormAlert!.color.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _weather!.stormAlert!.color.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.cyclone,
                                  color: _weather!.stormAlert!.color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _weather!.stormAlert!.color,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'CRITICAL',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _weather!.stormAlert!.title,
                                            style: GoogleFonts.inter(
                                              color:
                                                  _weather!.stormAlert!.color,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _weather!.stormAlert!.message,
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ─── Weather Dashboard ──────────────────────
                      if (_weatherLoading)
                        GlassContainer(
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: Color(0xFF4DD0E1),
                              ),
                            ),
                          ),
                        )
                      else if (_weatherError != null)
                        GlassContainer(
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.cloud_off,
                                  color: AppTheme.textDisabled,
                                  size: 36,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _weatherError!,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textDisabled,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_weather != null) ...[
                        // Location
                        if (_lat != null && _lon != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.my_location,
                                  size: 14,
                                  color: Color(0xFF4DD0E1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_lat!.toStringAsFixed(4)}°N, ${_lon!.toStringAsFixed(4)}°E',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF4DD0E1),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Weather main card
                        GlassContainer(
                          borderColor: AppTheme.fishermanColor.withValues(
                            alpha: 0.2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _weather!.weatherIcon,
                                    style: const TextStyle(fontSize: 42),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_weather!.temperature.toStringAsFixed(1)}°C',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          _weather!.weatherDescription,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF4DD0E1),
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
                                        style: GoogleFonts.inter(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${_weather!.humidity}% humidity',
                                        style: GoogleFonts.inter(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Weather grid tiles (Stitch-style 2-column)
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.6,
                          children: [
                            _WeatherTile(
                              icon: Icons.air,
                              label: 'Wind Speed',
                              value:
                                  '${_weather!.windSpeed.toStringAsFixed(0)} km/h',
                              color: AppTheme.fishermanColor,
                            ),
                            _WeatherTile(
                              icon: Icons.speed,
                              label: 'Gusts',
                              value:
                                  '${_weather!.windGusts.toStringAsFixed(0)} km/h',
                              color: AppTheme.fireColor,
                            ),
                            _WeatherTile(
                              icon: Icons.compress,
                              label: 'Pressure',
                              value:
                                  '${_weather!.pressure.toStringAsFixed(0)} hPa',
                              color: AppTheme.policeColor,
                            ),
                            if (_weather!.waveHeight != null)
                              _WeatherTile(
                                icon: Icons.waves,
                                label: 'Waves',
                                value:
                                    '${_weather!.waveHeight!.toStringAsFixed(1)}m',
                                color: AppTheme.fishermanColor,
                              ),
                            if (_weather!.swellHeight != null)
                              _WeatherTile(
                                icon: Icons.pool,
                                label: 'Swell',
                                value:
                                    '${_weather!.swellHeight!.toStringAsFixed(1)}m',
                                color: AppTheme.familyColor,
                              ),
                            _WeatherTile(
                              icon: Icons.sailing,
                              label: 'Sea',
                              value: _weather!.seaCondition,
                              color: AppTheme.policeColor,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),

                      // ─── SOS Button (Stitch gradient style) ─────
                      GestureDetector(
                        onTap: () => _sendFishermanSOS('General Emergency'),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.fishermanColor,
                                AppTheme.fishermanColor.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.fishermanColor.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'EMERGENCY',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'FISHERMAN SOS',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ─── Severity ───────────────────────────────
                      Text(
                        'SEVERITY LEVEL',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white54,
                          letterSpacing: 1.5,
                        ),
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
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withValues(alpha: 0.15)
                                      : AppTheme.surfaceCard.withValues(
                                          alpha: 0.4,
                                        ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? color.withValues(alpha: 0.6)
                                        : AppTheme.surfaceBorder,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    level,
                                    style: GoogleFonts.inter(
                                      color: isSelected
                                          ? color
                                          : AppTheme.textDisabled,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),

                      // ─── Emergency Types ────────────────────────
                      Text(
                        'SELECT EMERGENCY TYPE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white54,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(_subcategories.length, (i) {
                        final sub = _subcategories[i];
                        return GestureDetector(
                          onTap: () => _sendFishermanSOS(sub),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceCard.withValues(
                                alpha: 0.4,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.surfaceBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.fishermanColor.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber,
                                    color: Color(0xFF4DD0E1),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    sub,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: AppTheme.textDisabled,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Stitch-style Weather Tile ────────────────────────────────────────────────
class _WeatherTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _WeatherTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: AppTheme.textDisabled,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
