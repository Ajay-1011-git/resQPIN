import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/sos_model.dart';
import '../services/firestore_service.dart';
import '../services/sos_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/panic_service.dart';
import '../constants.dart';
import 'login_screen.dart';
import 'sos_category_screen.dart';
import 'sos_confirmation_dialog.dart';
import 'sos_tracking_screen.dart';
import 'fisherman_mode_screen.dart';
import 'family_screen.dart';
import 'family_tracking_screen.dart';
import 'heatmap_screen.dart';
import '../services/auth_service.dart';

class PublicDashboard extends StatefulWidget {
  const PublicDashboard({super.key});

  @override
  State<PublicDashboard> createState() => _PublicDashboardState();
}

class _PublicDashboardState extends State<PublicDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  final SOSService _sosService = SOSService();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final PanicService _panicService = PanicService();
  bool _isPanicRecording = false;

  UserModel? _user;
  bool _isLoading = true;

  // Family SOS alerts
  List<SOSModel> _familyAlerts = [];
  StreamSubscription? _familyAlertSub;
  final Set<String> _notifiedSOSIds =
      {}; // Track which SOS we already notified for

  @override
  void initState() {
    super.initState();
    _loadUser();
    _locationService.requestPermission();
    // Initialize panic service (volume triple-press → auto-SOS + recording)
    _panicService.initialize(onPanicTriggered: _onPanicTriggered);
  }

  @override
  void dispose() {
    _familyAlertSub?.cancel();
    _panicService.dispose();
    super.dispose();
  }

  /// Triggered by volume triple-press — auto-record audio + send POLICE HIGH alert
  Future<void> _onPanicTriggered() async {
    if (_user == null || _isPanicRecording) return;

    // Start audio recording
    final started = await _panicService.startRecording();
    if (mounted) setState(() => _isPanicRecording = started);

    // Auto-send POLICE HIGH SOS under Violence category
    try {
      final sos = await _sosService.createSOS(
        type: 'POLICE',
        subCategory: 'Violence — Panic Recording',
        severity: 'HIGH',
        createdBy: _user!.uid,
        createdByName: _user!.name,
        silent: true,
      );

      // Auto-stop recording after 60 seconds
      Future.delayed(const Duration(seconds: 60), () async {
        await _panicService.stopRecording();
        if (mounted) setState(() => _isPanicRecording = false);
      });

      if (mounted) _navigateToTracking(sos);
    } catch (e) {
      await _panicService.stopRecording();
      if (mounted) {
        setState(() => _isPanicRecording = false);
        _showError('Panic alert failed: $e');
      }
    }
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

      // Start listening for family SOS alerts
      _startFamilySOSListener(uid);
    }
  }

  void _startFamilySOSListener(String uid) {
    _familyAlertSub = _firestoreService.streamFamilySOSAlerts(uid).listen((
      alerts,
    ) {
      if (!mounted) return;

      // Trigger local notification for NEW alerts we haven't seen yet
      for (final alert in alerts) {
        if (!_notifiedSOSIds.contains(alert.sosId)) {
          _notifiedSOSIds.add(alert.sosId);
          _notificationService.showFamilyNotification(
            memberName: alert.createdByName ?? 'Family member',
            sosType: alert.subCategory ?? alert.type,
          );
        }
      }

      setState(() => _familyAlerts = alerts);
    });
  }

  Future<void> _triggerSOS(String sosType, {bool silent = false}) async {
    if (silent) {
      _showLoadingDialog('Sending silent alert...');
      try {
        final sos = await _sosService.createSOS(
          type: sosType,
          subCategory: 'Silent Emergency',
          severity: 'HIGH',
          createdBy: _user!.uid,
          createdByName: _user!.name,
          silent: true,
        );
        if (mounted) Navigator.pop(context);
        _navigateToTracking(sos);
      } catch (e) {
        if (mounted) Navigator.pop(context);
        _showError('Failed to send alert: $e');
      }
      return;
    }

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => SOSCategoryScreen(sosType: sosType)),
    );
    if (result == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SOSConfirmationDialog(
        sosType: sosType,
        subCategory: result['subCategory']!,
      ),
    );
    if (confirmed != true || !mounted) return;

    _showLoadingDialog('Sending alert...');
    try {
      final sos = await _sosService.createSOS(
        type: sosType,
        subCategory: result['subCategory']!,
        severity: result['severity']!,
        createdBy: _user!.uid,
        createdByName: _user!.name,
      );
      if (mounted) Navigator.pop(context);
      _navigateToTracking(sos);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Failed to send alert: $e');
    }
  }

  void _navigateToTracking(SOSModel sos) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SOSTrackingScreen(sosId: sos.sosId)),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ResQPIN'),
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
              // ─── Panic Recording Banner ───────────────────────────
              if (_isPanicRecording)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withValues(alpha: 0.4),
                        Colors.red.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: Colors.redAccent, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '🔴 RECORDING AUDIO — Panic alert sent',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _panicService.stopRecording();
                          if (mounted)
                            setState(() => _isPanicRecording = false);
                        },
                        child: const Text(
                          'STOP',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Family Alert Banner ──────────────────────────────
              if (_familyAlerts.isNotEmpty)
                ..._familyAlerts.map(
                  (alert) => _FamilyAlertBanner(
                    alert: alert,
                    onTrack: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FamilyTrackingScreen(sos: alert),
                      ),
                    ),
                  ),
                ),

              // ─── User Info Card ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome,',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _user?.name ?? '',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontSize: 22),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0D47A1,
                            ).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(
                                0xFF1565C0,
                              ).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            _user?.uniqueCode ?? '------',
                            style: const TextStyle(
                              color: Color(0xFF64B5F6),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _LiveClock(),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ─── Emergency Buttons ────────────────────────────────
              Text('Emergency', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _EmergencyButton(
                      icon: Icons.local_police,
                      label: 'Police',
                      color: kSOSTypeColors['POLICE']!,
                      onTap: () => _triggerSOS('POLICE'),
                      onLongPress: () => _triggerSOS('POLICE', silent: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EmergencyButton(
                      icon: Icons.local_fire_department,
                      label: 'Fire',
                      color: kSOSTypeColors['FIRE']!,
                      onTap: () => _triggerSOS('FIRE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EmergencyButton(
                      icon: Icons.local_hospital,
                      label: 'Ambulance',
                      color: kSOSTypeColors['AMBULANCE']!,
                      onTap: () => _triggerSOS('AMBULANCE'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Fisherman & Family Buttons ───────────────────────
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.sailing,
                      label: 'Fisherman Mode',
                      color: kSOSTypeColors['FISHERMAN']!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FishermanModeScreen(user: _user!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.family_restroom,
                      label: 'Family',
                      color: const Color(0xFF8E24AA),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FamilyScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Recent Alerts ────────────────────────────────────
              Text(
                'Recent Alerts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<List<SOSModel>>(
                  stream: _firestoreService.streamUserSOS(_user!.uid),
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
                      return const Center(
                        child: Text(
                          'No alerts yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: alerts.length,
                      itemBuilder: (context, i) {
                        final alert = alerts[i];
                        final typeColor =
                            kSOSTypeColors[alert.type] ?? Colors.grey;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                kSOSTypeIcons[alert.type],
                                color: typeColor,
                              ),
                            ),
                            title: Text(
                              '${alert.type} — ${alert.subCategory ?? ""}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Status: ${alert.status} • ${DateFormat('dd/MM HH:mm').format(alert.createdAt)}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            trailing: _statusBadge(alert.status),
                            onTap: () {
                              if (alert.status != 'CLOSED') {
                                _navigateToTracking(alert);
                              }
                            },
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

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'OPEN':
        color = Colors.orangeAccent;
        break;
      case 'ASSIGNED':
        color = Colors.blueAccent;
        break;
      case 'CLOSED':
        color = Colors.greenAccent;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Family Alert Banner ─────────────────────────────────────────────────────
class _FamilyAlertBanner extends StatelessWidget {
  final SOSModel alert;
  final VoidCallback onTrack;

  const _FamilyAlertBanner({required this.alert, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    final typeColor = kSOSTypeColors[alert.type] ?? Colors.redAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withValues(alpha: 0.3),
            typeColor.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.redAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ ${alert.createdByName ?? "Family member"} needs help!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${alert.type} — ${alert.subCategory ?? ""}',
                  style: TextStyle(color: typeColor, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTrack,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'TRACK',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Isolated clock widget — only this rebuilds every second, NOT the whole page
// ═══════════════════════════════════════════════════════════════════════════════
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
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

// ─── Emergency Button Widget ─────────────────────────────────────────────────
class _EmergencyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _EmergencyButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.15),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (onLongPress != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Hold for silent',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.5),
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Button Widget ───────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
