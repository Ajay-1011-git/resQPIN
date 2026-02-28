import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/sos_model.dart';
import '../models/user_model.dart';
import '../models/officer_location_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../constants.dart';

/// Screen for family members to track and navigate to an SOS location.
class FamilyTrackingScreen extends StatefulWidget {
  final SOSModel sos;

  const FamilyTrackingScreen({super.key, required this.sos});

  @override
  State<FamilyTrackingScreen> createState() => _FamilyTrackingScreenState();
}

class _FamilyTrackingScreenState extends State<FamilyTrackingScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;

  bool _isTracking = false;
  LatLng? _myPos;
  OfficerLocationModel? _officerLocation;
  SOSModel? _currentSOS;
  UserModel? _officerDetails;
  List<Map<String, dynamic>> _familyResponders = [];

  StreamSubscription? _sosSub;
  StreamSubscription? _officerSub;
  StreamSubscription? _familyRespondersSub;

  @override
  void initState() {
    super.initState();
    _currentSOS = widget.sos;
    _loadMyLocation();
    _startSOSStream();
    _startFamilyRespondersStream();
    _autoStartTracking();
  }

  @override
  void dispose() {
    _sosSub?.cancel();
    _officerSub?.cancel();
    _familyRespondersSub?.cancel();
    _locationService.stopLocationUpdates();
    _mapController?.dispose();
    super.dispose();
  }

  void _startSOSStream() {
    _sosSub = _firestoreService.streamSOS(widget.sos.sosId).listen((sos) {
      if (mounted && sos != null) {
        if (sos.status == 'ASSIGNED' &&
            sos.assignedOfficerId != null &&
            _currentSOS?.status != 'ASSIGNED') {
          _startOfficerTracking(sos.assignedOfficerId!);
          _loadOfficerDetails(sos.assignedOfficerId!);
        }
        setState(() => _currentSOS = sos);
      }
    });
  }

  void _startOfficerTracking(String officerId) {
    _officerSub?.cancel();
    _officerSub = _firestoreService.streamOfficerLocation(officerId).listen((
      location,
    ) {
      if (mounted && location != null) {
        setState(() => _officerLocation = location);
      }
    });
  }

  Future<void> _loadOfficerDetails(String officerId) async {
    final user = await _firestoreService.getUser(officerId);
    if (mounted && user != null) {
      setState(() => _officerDetails = user);
    }
  }

  void _startFamilyRespondersStream() {
    _familyRespondersSub = _firestoreService
        .streamFamilyResponders(widget.sos.sosId)
        .listen((responders) {
          if (mounted) setState(() => _familyResponders = responders);
        });
  }

  Future<void> _loadMyLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (mounted) setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  Future<void> _autoStartTracking() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (_myPos != null && !_isTracking && mounted) {
      await _startTracking();
    }
  }

  Future<void> _startTracking() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final user = await _firestoreService.getUser(uid);
    if (user == null || _myPos == null) return;

    await _firestoreService.addFamilyResponder(
      sosId: widget.sos.sosId,
      uid: uid,
      name: user.name,
      lat: _myPos!.latitude,
      lon: _myPos!.longitude,
    );

    _locationService.startLocationUpdates(
      onLocationChanged: (position) {
        if (mounted)
          setState(
            () => _myPos = LatLng(position.latitude, position.longitude),
          );
        _firestoreService.updateFamilyResponderLocation(
          sosId: widget.sos.sosId,
          uid: uid,
          lat: position.latitude,
          lon: position.longitude,
        );
      },
    );

    if (mounted) setState(() => _isTracking = true);
  }

  Future<void> _launchNavigation() async {
    final sos = _currentSOS ?? widget.sos;
    final url = Uri.parse('google.navigation:q=${sos.lat},${sos.lon}&mode=d');
    final fallback = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${sos.lat},${sos.lon}&travelmode=driving',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  void _dismissAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.surfaceBorder),
        ),
        title: Text(
          'Dismiss Alert?',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'You will stop tracking this alert. The officer will continue responding independently.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () {
              _locationService.stopLocationUpdates();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Dismiss',
              style: GoogleFonts.inter(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final sos = _currentSOS ?? widget.sos;

    markers.add(
      Marker(
        markerId: const MarkerId('sos_location'),
        position: LatLng(sos.lat, sos.lon),
        infoWindow: InfoWindow(
          title: 'SOS: ${sos.subCategory ?? sos.type}',
          snippet: sos.createdByName ?? 'Unknown',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    if (_officerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('officer_location'),
          position: LatLng(_officerLocation!.lat, _officerLocation!.lon),
          infoWindow: InfoWindow(
            title: sos.assignedOfficerName ?? 'Officer',
            snippet: _officerDetails?.department ?? '',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    for (final resp in _familyResponders) {
      final respUid = resp['uid'] as String? ?? '';
      if (respUid == myUid) continue;
      final lat = (resp['lat'] as num?)?.toDouble() ?? 0;
      final lon = (resp['lon'] as num?)?.toDouble() ?? 0;
      markers.add(
        Marker(
          markerId: MarkerId('family_$respUid'),
          position: LatLng(lat, lon),
          infoWindow: InfoWindow(title: '${resp['name'] ?? "Family"}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final sos = _currentSOS ?? widget.sos;
    final typeColor = kSOSTypeColors[sos.type] ?? Colors.blueAccent;
    final statusColor = AppTheme.statusColor(sos.status);

    String? distanceText;
    String? etaText;
    if (_myPos != null) {
      final d = LocationService.calculateDistance(
        _myPos!.latitude,
        _myPos!.longitude,
        sos.lat,
        sos.lon,
      );
      distanceText = LocationService.formatDistance(d);
      etaText = LocationService.estimateETA(d);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Family Tracking',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.orangeAccent),
            tooltip: 'Dismiss Alert',
            onPressed: _dismissAlert,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Map ─────────────────────────────────────────
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(sos.lat, sos.lon),
                zoom: 14,
              ),
              markers: _buildMarkers(),
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),

          // ─── Frosted Info Panel ──────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgPrimary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PulsingDot(color: statusColor, size: 6),
                          const SizedBox(width: 8),
                          Text(
                            sos.status == 'ASSIGNED'
                                ? 'Officer responding'
                                : sos.status == 'CLOSED'
                                ? 'Resolved'
                                : 'Waiting for officer...',
                            style: GoogleFonts.inter(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Alert info
                    Text(
                      '${sos.createdByName ?? "Someone"} needs help!',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sos.type} — ${sos.subCategory ?? ""}',
                      style: GoogleFonts.inter(color: typeColor, fontSize: 14),
                    ),
                    const SizedBox(height: 12),

                    // Distance & ETA
                    if (distanceText != null && etaText != null)
                      Row(
                        children: [
                          _Chip(
                            icon: Icons.place,
                            label: distanceText,
                            color: AppTheme.statusOpen,
                          ),
                          const SizedBox(width: 10),
                          _Chip(
                            icon: Icons.timer,
                            label: 'ETA: $etaText',
                            color: AppTheme.ambulanceColor,
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),

                    // Officer details
                    if (sos.status == 'ASSIGNED' && _officerDetails != null)
                      GlassContainer(
                        padding: const EdgeInsets.all(12),
                        borderRadius: 12,
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.policeColor.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                              child: const Icon(
                                Icons.security,
                                color: AppTheme.policeColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _officerDetails!.name,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${_officerDetails!.department ?? ""} • ${_officerDetails!.phone}',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Family responders
                    if (_familyResponders.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.family_restroom,
                            size: 16,
                            color: AppTheme.ambulanceColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_familyResponders.length} family member(s) tracking',
                            style: GoogleFonts.inter(
                              color: AppTheme.ambulanceColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // ─── Action Buttons ──────────────────────────
                    if (sos.status != 'CLOSED') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _launchNavigation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.policeColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.navigation, size: 20),
                          label: Text(
                            'NAVIGATE (Google Maps)',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _dismissAlert,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orangeAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.orangeAccent,
                            size: 18,
                          ),
                          label: Text(
                            'DISMISS ALERT',
                            style: GoogleFonts.inter(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Tracking status
                    if (_isTracking) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.ambulanceColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.ambulanceColor.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PulsingDot(color: AppTheme.ambulanceColor, size: 6),
                            const SizedBox(width: 10),
                            Text(
                              'Your location is being shared',
                              style: GoogleFonts.inter(
                                color: AppTheme.ambulanceColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Resolved state
                    if (sos.status == 'CLOSED') ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.ambulanceColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.ambulanceColor.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.ambulanceColor,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This alert has been resolved',
                              style: GoogleFonts.inter(
                                color: AppTheme.ambulanceColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
