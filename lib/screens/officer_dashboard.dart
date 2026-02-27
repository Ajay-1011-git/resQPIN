import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/sos_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../models/officer_location_model.dart';
import '../constants.dart';
import 'alert_detail_screen.dart';
import 'login_screen.dart';
import 'heatmap_screen.dart';

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = true;
  double? _myLat;
  double? _myLon;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final user = await _firestoreService.getUser(uid);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }

      final hasPermission = await _locationService.requestPermission();
      if (hasPermission) {
        try {
          final pos = await _locationService.getCurrentPosition();
          _myLat = pos.latitude;
          _myLon = pos.longitude;

          _locationService.startLocationUpdates(
            onLocationChanged: (position) {
              _myLat = position.latitude;
              _myLon = position.longitude;
              _firestoreService.updateOfficerLocation(
                OfficerLocationModel(
                  officerId: uid,
                  lat: position.latitude,
                  lon: position.longitude,
                  updatedAt: DateTime.now(),
                ),
              );
              // Only update location-related state, not the whole page
              if (mounted) setState(() {});
            },
          );
        } catch (_) {}
      }
    }
  }

  String get _sosTypeForDepartment {
    return kDepartmentToSOSType[_user?.department] ?? 'POLICE';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final departmentColor =
        kSOSTypeColors[_sosTypeForDepartment] ?? Colors.blueAccent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Crime Heatmap',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HeatmapScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              _locationService.stopLocationUpdates();
              await _authService.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Officer Info Card ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      departmentColor.withValues(alpha: 0.2),
                      const Color(0xFF1A1A2E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: departmentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: departmentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.shield,
                            color: departmentColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user?.name ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: departmentColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _user?.department ?? '',
                                  style: TextStyle(
                                    color: departmentColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Isolated clock — only this rebuilds every second
                    _OfficerClock(color: departmentColor),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─── Open Alerts Header ───────────────────────────────
              Row(
                children: [
                  Text(
                    'Open Alerts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: departmentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _sosTypeForDepartment,
                      style: TextStyle(
                        color: departmentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ─── Alert List ───────────────────────────────────────
              Expanded(
                child: StreamBuilder<List<SOSModel>>(
                  stream: _firestoreService.streamOpenSOSByType(
                    _sosTypeForDepartment,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Error loading alerts:\n${snapshot.error}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final alerts = snapshot.data ?? [];
                    if (alerts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 60,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No open alerts',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: alerts.length,
                      itemBuilder: (context, i) {
                        final alert = alerts[i];
                        final severityColor =
                            kSeverityColors[alert.severity] ??
                            Colors.orangeAccent;
                        String distanceText = '';
                        if (_myLat != null && _myLon != null) {
                          final d = LocationService.calculateDistance(
                            _myLat!,
                            _myLon!,
                            alert.lat,
                            alert.lon,
                          );
                          distanceText = LocationService.formatDistance(d);
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AlertDetailScreen(
                                  sos: alert,
                                  officerUser: _user!,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: severityColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                alert.subCategory ?? alert.type,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: severityColor.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                alert.severity,
                                                style: TextStyle(
                                                  color: severityColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 14,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat(
                                                'HH:mm',
                                              ).format(alert.createdAt),
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (distanceText.isNotEmpty) ...[
                                              const SizedBox(width: 16),
                                              Icon(
                                                Icons.place,
                                                size: 14,
                                                color: Colors.grey.shade500,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                distanceText,
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                            if (alert.silent) ...[
                                              const SizedBox(width: 16),
                                              const Icon(
                                                Icons.volume_off,
                                                size: 14,
                                                color: Colors.redAccent,
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'SILENT',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Isolated officer clock — only this widget rebuilds every second
// ═══════════════════════════════════════════════════════════════════════════════
class _OfficerClock extends StatefulWidget {
  final Color color;
  const _OfficerClock({required this.color});

  @override
  State<_OfficerClock> createState() => _OfficerClockState();
}

class _OfficerClockState extends State<_OfficerClock> {
  late Timer _timer;
  String _time = '';
  String _date = '';

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _update() {
    final now = DateTime.now();
    setState(() {
      _time = DateFormat('hh:mm:ss a').format(now);
      _date = DateFormat('EEEE, dd MMMM yyyy').format(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_date, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          _time,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 22,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
