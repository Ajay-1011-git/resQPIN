import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/user_model.dart';
import '../models/sos_model.dart';
import '../services/firestore_service.dart';
import '../services/sos_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/panic_service.dart';
import '../constants.dart';
import '../utils/animations.dart';
import '../widgets/emergency_button.dart';
import '../widgets/glass_widgets.dart';
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

  List<SOSModel> _familyAlerts = [];
  StreamSubscription? _familyAlertSub;
  final Set<String> _notifiedSOSIds = {};
  final Set<String> _dismissedSOSIds = {};

  @override
  void initState() {
    super.initState();
    _loadUser();
    _locationService.requestPermission();
    _panicService.initialize(onPanicTriggered: _onPanicTriggered);
    // Pre-request mic permission so panic recording works immediately
    _panicService.requestMicPermission();
  }

  @override
  void dispose() {
    _familyAlertSub?.cancel();
    _panicService.dispose();
    super.dispose();
  }

  Future<void> _onPanicTriggered() async {
    if (_user == null || _isPanicRecording) return;
    final activeSOS = await _firestoreService.getActiveSOSForUser(_user!.uid);
    if (activeSOS != null) {
      if (mounted) _navigateToTracking(activeSOS);
      return;
    }
    final started = await _panicService.startRecording();
    if (mounted) setState(() => _isPanicRecording = started);
    try {
      final sos = await _sosService.createSOS(
        type: 'POLICE',
        subCategory: 'Violence — Panic Recording',
        severity: 'HIGH',
        createdBy: _user!.uid,
        createdByName: _user!.name,
        silent: true,
      );
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
      _startFamilySOSListener(uid);
    }
  }

  void _startFamilySOSListener(String uid) {
    _familyAlertSub = _firestoreService.streamFamilySOSAlerts(uid).listen((
      alerts,
    ) {
      if (!mounted) return;
      // Deduplicate by sosId
      final seen = <String>{};
      final uniqueAlerts = <SOSModel>[];
      for (final alert in alerts) {
        if (seen.add(alert.sosId)) {
          uniqueAlerts.add(alert);
        }
      }
      for (final alert in uniqueAlerts) {
        if (!_notifiedSOSIds.contains(alert.sosId)) {
          _notifiedSOSIds.add(alert.sosId);
          _notificationService.showFamilyNotification(
            memberName: alert.createdByName ?? 'Family member',
            sosType: alert.subCategory ?? alert.type,
          );
        }
      }
      setState(() => _familyAlerts = uniqueAlerts);
    });
  }

  Future<void> _triggerSOS(String sosType, {bool silent = false}) async {
    final activeSOS = await _firestoreService.getActiveSOSForUser(_user!.uid);
    if (activeSOS != null) {
      _showError('You already have an active alert. Resolve it first.');
      _navigateToTracking(activeSOS);
      return;
    }

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
      AppTheme.fadeSlideRoute(SOSCategoryScreen(sosType: sosType)),
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
      AppTheme.fadeSlideRoute(SOSTrackingScreen(sosId: sos.sosId)),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        toolbarHeight: 64,
        title: Text(
          'ResQPIN',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined, size: 26),
            tooltip: 'Crime Heatmap',
            onPressed: () => Navigator.push(
              context,
              AppTheme.fadeSlideRoute(const HeatmapScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 26),
            tooltip: 'Logout',
            onPressed: () async {
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ─── Panic Recording Banner ────────────────────────
                if (_isPanicRecording) _buildPanicBanner(),

                // ─── Family Alert Banners (max 2 visible) ──────
                if (_familyAlerts.isNotEmpty)
                  ..._familyAlerts
                      .where((a) => !_dismissedSOSIds.contains(a.sosId))
                      .take(2)
                      .map(
                        (alert) => _FamilyAlertBanner(
                          alert: alert,
                          onTrack: () => Navigator.push(
                            context,
                            AppTheme.fadeSlideRoute(
                              FamilyTrackingScreen(sos: alert),
                            ),
                          ),
                          onDismiss: () =>
                              setState(() => _dismissedSOSIds.add(alert.sosId)),
                        ),
                      ),

                // ─── User Info Card ────────────────────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: GlassContainer(
                    glowColor: AppTheme.policeColor,
                    child: Row(
                      children: [
                        // Avatar circle with gradient border
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.policeColor.withValues(alpha: 0.3),
                                AppTheme.accentPurple.withValues(alpha: 0.2),
                              ],
                            ),
                            border: Border.all(
                              color: AppTheme.policeColor.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              (_user?.name.isNotEmpty == true)
                                  ? _user!.name[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.policeColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _user?.name ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              GlassInfoChip(
                                icon: Icons.fingerprint,
                                label: _user?.uniqueCode ?? '------',
                                color: AppTheme.policeColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // ─── Emergency Services ────────────────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    'EMERGENCY SERVICES',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 250),
                  child: Row(
                    children: [
                      Expanded(
                        child: EmergencyButton(
                          icon: Icons.local_police,
                          label: 'Police',
                          color: AppTheme.policeColor,
                          onTap: () => _triggerSOS('POLICE'),
                          onLongPress: () =>
                              _triggerSOS('POLICE', silent: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EmergencyButton(
                          icon: Icons.local_fire_department,
                          label: 'Fire',
                          color: AppTheme.fireColor,
                          onTap: () => _triggerSOS('FIRE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EmergencyButton(
                          icon: Icons.local_hospital,
                          label: 'Medic',
                          color: AppTheme.ambulanceColor,
                          onTap: () => _triggerSOS('AMBULANCE'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ─── Utility Buttons ───────────────────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 350),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassUtilityButton(
                          icon: Icons.sailing,
                          label: 'Fisherman Mode',
                          color: AppTheme.fishermanColor,
                          onTap: () => Navigator.push(
                            context,
                            AppTheme.fadeSlideRoute(
                              FishermanModeScreen(user: _user!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassUtilityButton(
                          icon: Icons.family_restroom,
                          label: 'Family Circle',
                          color: AppTheme.familyColor,
                          onTap: () => Navigator.push(
                            context,
                            AppTheme.fadeSlideRoute(const FamilyScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ─── Recent Alerts ─────────────────────────────────
                Text(
                  'RECENT ALERTS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white54,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<List<SOSModel>>(
                    stream: _firestoreService.streamUserSOS(_user!.uid),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final alerts = snapshot.data ?? [];
                      if (alerts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No alerts yet',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textDisabled,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: alerts.length,
                        itemBuilder: (context, i) => _AlertCard(
                          alert: alerts[i],
                          onTap: () {
                            if (alerts[i].status != 'CLOSED') {
                              _navigateToTracking(alerts[i]);
                            }
                          },
                        ),
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

  Widget _buildPanicBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withValues(alpha: 0.25),
            Colors.red.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const PulsingDot(color: Colors.redAccent, size: 10),
          const SizedBox(width: 12),
          const Icon(Icons.mic, color: Colors.redAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'RECORDING AUDIO',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _panicService.stopRecording();
              if (mounted) setState(() => _isPanicRecording = false);
            },
            child: Text(
              'STOP',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Alert Card with glassmorphism ───────────────────────────────────────────
class _AlertCard extends StatefulWidget {
  final SOSModel alert;
  final VoidCallback onTap;

  const _AlertCard({required this.alert, required this.onTap});

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final typeColor = kSOSTypeColors[widget.alert.type] ?? Colors.grey;
    final statusColor = AppTheme.statusColor(widget.alert.status);
    final isOpen = widget.alert.status == 'OPEN';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? typeColor.withValues(alpha: 0.25)
                  : AppTheme.surfaceBorder,
            ),
            boxShadow: [
              if (isOpen)
                BoxShadow(
                  color: typeColor.withValues(alpha: 0.08),
                  blurRadius: 16,
                  spreadRadius: -6,
                ),
            ],
          ),
          child: Row(
            children: [
              // Type icon with gradient background
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: typeColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  kSOSTypeIcons[widget.alert.type],
                  color: typeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.alert.subCategory ?? widget.alert.type,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM HH:mm').format(widget.alert.createdAt),
                      style: GoogleFonts.inter(
                        color: AppTheme.textDisabled,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              GlassStatusBadge(
                label: widget.alert.status,
                color: statusColor,
                isActive: isOpen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Family Alert Banner ───────────────────────────────────────────────────
class _FamilyAlertBanner extends StatelessWidget {
  final SOSModel alert;
  final VoidCallback onTrack;
  final VoidCallback onDismiss;

  const _FamilyAlertBanner({
    required this.alert,
    required this.onTrack,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withValues(alpha: 0.2),
            Colors.red.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.2),
                ),
                child: const Icon(
                  Icons.warning_amber,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alert.createdByName ?? "Family member"} needs help!',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${alert.type} — ${alert.subCategory ?? ""}',
                      style: GoogleFonts.inter(
                        color: Colors.redAccent.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTrack,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.navigation, size: 18),
              label: Text(
                'TRACK & NAVIGATE',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
