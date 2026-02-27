import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/sos_model.dart';
import '../models/user_model.dart';
import '../models/officer_location_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../constants.dart';

/// Screen for family members to track and navigate to an SOS location.
/// Multiple family members can track simultaneously.
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
        // Start officer tracking when assigned
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
          if (mounted) {
            setState(() => _familyResponders = responders);
          }
        });
  }

  Future<void> _loadMyLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  Future<void> _startTracking() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final user = await _firestoreService.getUser(uid);
    if (user == null || _myPos == null) return;

    // Register as family responder
    await _firestoreService.addFamilyResponder(
      sosId: widget.sos.sosId,
      uid: uid,
      name: user.name,
      lat: _myPos!.latitude,
      lon: _myPos!.longitude,
    );

    // Start continuous location updates
    _locationService.startLocationUpdates(
      onLocationChanged: (position) {
        if (mounted) {
          setState(
            () => _myPos = LatLng(position.latitude, position.longitude),
          );
        }
        _firestoreService.updateFamilyResponderLocation(
          sosId: widget.sos.sosId,
          uid: uid,
          lat: position.latitude,
          lon: position.longitude,
        );
      },
    );

    setState(() => _isTracking = true);
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final sos = _currentSOS ?? widget.sos;

    // SOS location (red)
    markers.add(
      Marker(
        markerId: const MarkerId('sos_location'),
        position: LatLng(sos.lat, sos.lon),
        infoWindow: InfoWindow(
          title: '📍 SOS: ${sos.subCategory ?? sos.type}',
          snippet: sos.createdByName ?? 'Unknown',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // Officer location (blue)
    if (_officerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('officer_location'),
          position: LatLng(_officerLocation!.lat, _officerLocation!.lon),
          infoWindow: InfoWindow(
            title: '🚔 ${sos.assignedOfficerName ?? "Officer"}',
            snippet: _officerDetails?.department ?? '',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Family responders (green) — exclude self
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
          infoWindow: InfoWindow(title: '👨‍👩‍👧 ${resp['name'] ?? "Family"}'),
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
    final statusColor = sos.status == 'ASSIGNED'
        ? Colors.blueAccent
        : sos.status == 'CLOSED'
        ? Colors.greenAccent
        : Colors.orangeAccent;

    // Distance/ETA from SOS
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
      appBar: AppBar(
        title: const Text('Family Tracking'),
        backgroundColor: typeColor.withValues(alpha: 0.2),
      ),
      body: Column(
        children: [
          // ─── Map ──────────────────────────────────────────────
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

          // ─── Info Panel ──────────────────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sos.status == 'ASSIGNED'
                                ? 'Officer responding'
                                : sos.status == 'CLOSED'
                                ? 'Resolved'
                                : 'Waiting for officer...',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Alert info
                    Text(
                      '${sos.createdByName ?? "Someone"} needs help!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sos.type} — ${sos.subCategory ?? ""}',
                      style: TextStyle(color: typeColor, fontSize: 14),
                    ),
                    const SizedBox(height: 12),

                    // Distance & ETA
                    if (distanceText != null && etaText != null)
                      Row(
                        children: [
                          _Chip(
                            icon: Icons.place,
                            label: distanceText,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(width: 12),
                          _Chip(
                            icon: Icons.timer,
                            label: 'ETA: $etaText',
                            color: Colors.greenAccent,
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),

                    // Officer details
                    if (sos.status == 'ASSIGNED' &&
                        _officerDetails != null) ...[
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.shield,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _officerDetails!.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${_officerDetails!.department ?? ""} • ${_officerDetails!.phone}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Family responders count
                    if (_familyResponders.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.family_restroom,
                            color: Colors.greenAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_familyResponders.length} family member(s) tracking',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Track button
                    if (!_isTracking && sos.status != 'CLOSED')
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _myPos == null ? null : _startTracking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.navigation, size: 22),
                          label: const Text(
                            'START TRACKING',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    if (_isTracking)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.my_location,
                              color: Colors.greenAccent,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Your location is being shared',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
