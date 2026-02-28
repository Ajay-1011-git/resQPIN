import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Officer Dashboard',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Crime Heatmap',
            onPressed: () => Navigator.push(
              context,
              AppTheme.fadeSlideRoute(const HeatmapScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              _locationService.stopLocationUpdates();
              await _authService.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  AppTheme.fadeSlideRoute(const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: LiquidBackground(
        accentColor: departmentColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ─── Officer Info Card (Stitch-style) ─────────────
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Shield icon in colored circle
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: departmentColor.withValues(alpha: 0.15),
                              border: Border.all(
                                color: departmentColor.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.security,
                              color: departmentColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _user?.name ?? '',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: departmentColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _user?.department ?? '',
                                        style: GoogleFonts.inter(
                                          color: departmentColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // On Duty badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.ambulanceColor
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PulsingDot(
                                            color: AppTheme.ambulanceColor,
                                            size: 5,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'ON DUTY',
                                            style: GoogleFonts.inter(
                                              color: AppTheme.ambulanceColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _OfficerClock(color: departmentColor),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ─── Section header ────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: AppTheme.statusOpen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LIVE ALERTS',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: departmentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _sosTypeForDepartment,
                        style: GoogleFonts.inter(
                          color: departmentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Alert List: ASSIGNED (my) + OPEN ──────────────
                Expanded(
                  child: StreamBuilder<List<SOSModel>>(
                    stream: _firestoreService.streamAssignedSOSByOfficer(
                      FirebaseAuth.instance.currentUser!.uid,
                    ),
                    builder: (context, assignedSnap) {
                      return StreamBuilder<List<SOSModel>>(
                        stream: _firestoreService.streamOpenSOSByType(
                          _sosTypeForDepartment,
                        ),
                        builder: (context, openSnap) {
                          if (openSnap.hasError || assignedSnap.hasError) {
                            return Center(
                              child: Text(
                                'Error loading alerts',
                                style: GoogleFonts.inter(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }
                          if (openSnap.connectionState ==
                                  ConnectionState.waiting &&
                              assignedSnap.connectionState ==
                                  ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final myAlerts = assignedSnap.data ?? [];
                          final openAlerts = openSnap.data ?? [];

                          if (myAlerts.isEmpty && openAlerts.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 52,
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No open alerts',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textDisabled,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final allAlerts = [...myAlerts, ...openAlerts];
                          final myAlertIds = myAlerts
                              .map((a) => a.sosId)
                              .toSet();

                          return ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: allAlerts.length,
                            itemBuilder: (context, i) {
                              final alert = allAlerts[i];
                              final isMyAlert = myAlertIds.contains(
                                alert.sosId,
                              );
                              return _OfficerAlertCard(
                                alert: alert,
                                isMyAlert: isMyAlert,
                                myLat: _myLat,
                                myLon: _myLon,
                                onTap: () => Navigator.push(
                                  context,
                                  AppTheme.fadeSlideRoute(
                                    AlertDetailScreen(
                                      sos: alert,
                                      officerUser: _user!,
                                    ),
                                  ),
                                ),
                              );
                            },
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
      ),
    );
  }
}

// ─── Stitch-style alert card with colored left border ────────────────────────
class _OfficerAlertCard extends StatelessWidget {
  final SOSModel alert;
  final bool isMyAlert;
  final double? myLat;
  final double? myLon;
  final VoidCallback onTap;

  const _OfficerAlertCard({
    required this.alert,
    required this.isMyAlert,
    required this.myLat,
    required this.myLon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final severityColor =
        kSeverityColors[alert.severity] ?? Colors.orangeAccent;
    final borderColor = isMyAlert ? AppTheme.ambulanceColor : severityColor;
    String distanceText = '';
    if (myLat != null && myLon != null) {
      final d = LocationService.calculateDistance(
        myLat!,
        myLon!,
        alert.lat,
        alert.lon,
      );
      distanceText = LocationService.formatDistance(d);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Row(
          children: [
            // Stitch left border accent
            Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Alert content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + badge row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.subCategory ?? alert.type,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isMyAlert
                                        ? AppTheme.ambulanceColor
                                        : severityColor)
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isMyAlert ? 'ASSIGNED' : alert.severity,
                            style: GoogleFonts.inter(
                              color: isMyAlert
                                  ? AppTheme.ambulanceColor
                                  : severityColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Reporter name
                    if (alert.createdByName != null)
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            alert.createdByName!,
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    // Meta row
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: AppTheme.textDisabled,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('HH:mm').format(alert.createdAt),
                          style: GoogleFonts.inter(
                            color: AppTheme.textDisabled,
                            fontSize: 11,
                          ),
                        ),
                        if (distanceText.isNotEmpty) ...[
                          const SizedBox(width: 14),
                          Icon(
                            Icons.place,
                            size: 13,
                            color: AppTheme.textDisabled,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distanceText,
                            style: GoogleFonts.inter(
                              color: AppTheme.textDisabled,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (alert.silent) ...[
                          const SizedBox(width: 14),
                          Icon(
                            Icons.volume_off,
                            size: 13,
                            color: AppTheme.fireColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'SILENT',
                            style: GoogleFonts.inter(
                              color: AppTheme.fireColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'Respond →',
                style: GoogleFonts.inter(
                  color: AppTheme.policeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Officer Clock ───────────────────────────────────────────────────────────
class _OfficerClock extends StatefulWidget {
  final Color color;
  const _OfficerClock({required this.color});

  @override
  State<_OfficerClock> createState() => _OfficerClockState();
}

class _OfficerClockState extends State<_OfficerClock> {
  late Timer _timer;
  String _h = '00';
  String _m = '00';
  String _s = '00';
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
      _h = DateFormat('HH').format(now);
      _m = DateFormat('mm').format(now);
      _s = DateFormat('ss').format(now);
      _date = DateFormat('EEE, dd MMM yyyy').format(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _date,
          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _clockDigit(_h),
            _clockSep(),
            _clockDigit(_m),
            _clockSep(),
            _clockDigit(_s),
          ],
        ),
      ],
    );
  }

  Widget _clockDigit(String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.color.withValues(alpha: 0.2)),
      ),
      child: Text(
        val,
        style: GoogleFonts.robotoMono(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _clockSep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: GoogleFonts.robotoMono(
          color: AppTheme.textSecondary,
          fontSize: 18,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
