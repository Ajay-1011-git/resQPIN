import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../app_theme.dart';
import '../models/sos_model.dart';
import '../models/user_model.dart';
import '../models/officer_location_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';

class SOSTrackingScreen extends StatefulWidget {
  final String sosId;

  const SOSTrackingScreen({super.key, required this.sosId});

  @override
  State<SOSTrackingScreen> createState() => _SOSTrackingScreenState();
}

class _SOSTrackingScreenState extends State<SOSTrackingScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  GoogleMapController? _mapController;
  SOSModel? _sos;
  OfficerLocationModel? _officerLocation;
  UserModel? _officerDetails;
  List<Map<String, dynamic>> _familyResponders = [];
  StreamSubscription? _officerLocationSub;
  StreamSubscription? _familyRespondersSub;

  @override
  void initState() {
    super.initState();
    _startFamilyRespondersStream();
  }

  @override
  void dispose() {
    _officerLocationSub?.cancel();
    _familyRespondersSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startOfficerTracking(String officerId) {
    _officerLocationSub?.cancel();
    _officerLocationSub = _firestoreService
        .streamOfficerLocation(officerId)
        .listen((location) {
          if (mounted && location != null) {
            setState(() => _officerLocation = location);
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(LatLng(location.lat, location.lon)),
            );
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
        .streamFamilyResponders(widget.sosId)
        .listen((responders) {
          if (mounted) {
            setState(() => _familyResponders = responders);
          }
        });
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    if (_sos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('sos_location'),
          position: LatLng(_sos!.lat, _sos!.lon),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (_officerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('officer_location'),
          position: LatLng(_officerLocation!.lat, _officerLocation!.lon),
          infoWindow: InfoWindow(
            title: _sos?.assignedOfficerName ?? 'Officer',
            snippet: _officerDetails?.department ?? '',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    for (final resp in _familyResponders) {
      final uid = resp['uid'] as String? ?? '';
      final lat = (resp['lat'] as num?)?.toDouble() ?? 0;
      final lon = (resp['lon'] as num?)?.toDouble() ?? 0;
      markers.add(
        Marker(
          markerId: MarkerId('family_$uid'),
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

  String _getStatusText(String status) {
    switch (status) {
      case 'OPEN':
        return 'Waiting for officer...';
      case 'ASSIGNED':
        return 'Officer is on the way!';
      case 'CLOSED':
        return 'Emergency resolved';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    return AppTheme.statusColor(status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'SOS Tracker',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<SOSModel?>(
        stream: _firestoreService.streamSOS(widget.sosId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _sos == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data != null) {
            final newSOS = snapshot.data!;
            if (newSOS.status == 'ASSIGNED' &&
                newSOS.assignedOfficerId != null &&
                _sos?.status != 'ASSIGNED') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _startOfficerTracking(newSOS.assignedOfficerId!);
                _loadOfficerDetails(newSOS.assignedOfficerId!);
              });
            }
            _sos = newSOS;
          }

          if (_sos == null) {
            return Center(
              child: Text(
                'Alert not found',
                style: GoogleFonts.inter(color: AppTheme.textSecondary),
              ),
            );
          }

          final statusColor = _getStatusColor(_sos!.status);
          String? distance;
          String? eta;
          if (_officerLocation != null) {
            final d = LocationService.calculateDistance(
              _sos!.lat,
              _sos!.lon,
              _officerLocation!.lat,
              _officerLocation!.lon,
            );
            distance = LocationService.formatDistance(d);
            eta = LocationService.estimateETA(d);
          }

          return Column(
            children: [
              // ─── Map ────────────────────────────────────────
              Expanded(
                flex: 3,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_sos!.lat, _sos!.lon),
                    zoom: 15,
                  ),
                  markers: _buildMarkers(),
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),

              // ─── Frosted Status Panel ────────────────────────
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
                    border: Border(
                      top: BorderSide(color: AppTheme.surfaceBorder),
                    ),
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
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Status badge with pulsing dot
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
                                _getStatusText(_sos!.status),
                                style: GoogleFonts.inter(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Alert type & sub-category
                        Row(
                          children: [
                            Expanded(
                              child: GlassContainer(
                                padding: const EdgeInsets.all(12),
                                borderRadius: 12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ALERT',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.textDisabled,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _sos!.type,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassContainer(
                                padding: const EdgeInsets.all(12),
                                borderRadius: 12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CATEGORY',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.textDisabled,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _sos!.subCategory ?? 'N/A',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // DIGIPIN pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.policeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.policeColor.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pin_drop,
                                size: 14,
                                color: AppTheme.policeColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _sos!.digipin,
                                style: GoogleFonts.robotoMono(
                                  color: AppTheme.policeColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ETA + Distance chips
                        if (distance != null && eta != null)
                          Row(
                            children: [
                              _InfoChip(
                                icon: Icons.timer,
                                label: 'ETA: $eta',
                                color: AppTheme.ambulanceColor,
                              ),
                              const SizedBox(width: 10),
                              _InfoChip(
                                icon: Icons.place,
                                label: distance,
                                color: AppTheme.statusOpen,
                              ),
                            ],
                          ),

                        // Officer info
                        if (_sos!.status == 'ASSIGNED') ...[
                          const SizedBox(height: 14),
                          GlassContainer(
                            padding: const EdgeInsets.all(14),
                            borderRadius: 14,
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.policeColor.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.security,
                                    color: AppTheme.policeColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _sos!.assignedOfficerName ?? 'Officer',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (_officerDetails != null)
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
                        ],

                        // Family responders
                        if (_familyResponders.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          GlassContainer(
                            padding: const EdgeInsets.all(14),
                            borderRadius: 14,
                            child: Column(
                              children: [
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
                                const SizedBox(height: 8),
                                ..._familyResponders.map((resp) {
                                  final name = resp['name'] ?? 'Family';
                                  final lat =
                                      (resp['lat'] as num?)?.toDouble() ?? 0;
                                  final lon =
                                      (resp['lon'] as num?)?.toDouble() ?? 0;
                                  String respDist = '';
                                  if (_sos != null) {
                                    final d = LocationService.calculateDistance(
                                      _sos!.lat,
                                      _sos!.lon,
                                      lat,
                                      lon,
                                    );
                                    respDist = LocationService.formatDistance(
                                      d,
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.person,
                                          color: AppTheme.ambulanceColor,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            name.toString(),
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        if (respDist.isNotEmpty)
                                          Text(
                                            respDist,
                                            style: GoogleFonts.inter(
                                              color: AppTheme.textDisabled,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],

                        // Resolution times
                        if (_sos!.status == 'CLOSED') ...[
                          const SizedBox(height: 14),
                          GlassContainer(
                            padding: const EdgeInsets.all(14),
                            borderRadius: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_sos!.timeToAssign != null)
                                  Text(
                                    'Time to assign: ${_sos!.timeToAssign!.inMinutes}m ${_sos!.timeToAssign!.inSeconds % 60}s',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (_sos!.totalResolutionTime != null)
                                  Text(
                                    'Total time: ${_sos!.totalResolutionTime!.inMinutes}m ${_sos!.totalResolutionTime!.inSeconds % 60}s',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
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
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

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
