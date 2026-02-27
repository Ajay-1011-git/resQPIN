import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/sos_model.dart';
import '../models/officer_location_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../utils/map_styles.dart';

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
  StreamSubscription? _officerLocationSub;

  @override
  void dispose() {
    _officerLocationSub?.cancel();
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
            // Animate camera to officer
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(LatLng(location.lat, location.lon)),
            );
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
          infoWindow: InfoWindow(title: _sos?.assignedOfficerName ?? 'Officer'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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
    switch (status) {
      case 'OPEN':
        return Colors.orangeAccent;
      case 'ASSIGNED':
        return Colors.blueAccent;
      case 'CLOSED':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS Tracker')),
      body: StreamBuilder<SOSModel?>(
        stream: _firestoreService.streamSOS(widget.sosId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _sos == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data != null) {
            final newSOS = snapshot.data!;
            // Start tracking officer when assigned
            if (newSOS.status == 'ASSIGNED' &&
                newSOS.assignedOfficerId != null &&
                _sos?.status != 'ASSIGNED') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _startOfficerTracking(newSOS.assignedOfficerId!);
              });
            }
            _sos = newSOS;
          }

          if (_sos == null) {
            return const Center(child: Text('Alert not found'));
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
              // ─── Map ────────────────────────────────────────────
              Expanded(
                flex: 3,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_sos!.lat, _sos!.lon),
                    zoom: 15,
                  ),
                  markers: _buildMarkers(),
                  style: MapStyles.darkStyle,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),

              // ─── Status Panel ───────────────────────────────────
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
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
                                _getStatusText(_sos!.status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Alert info
                        Text(
                          '${_sos!.type} — ${_sos!.subCategory ?? ""}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'DIGIPIN: ${_sos!.digipin}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Officer info (when assigned)
                        if (_sos!.status == 'ASSIGNED') ...[
                          const Divider(color: Colors.grey),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.shield,
                                color: Colors.blueAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _sos!.assignedOfficerName ?? 'Officer',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (distance != null && eta != null)
                            Row(
                              children: [
                                _InfoChip(
                                  icon: Icons.place,
                                  label: distance,
                                  color: Colors.orangeAccent,
                                ),
                                const SizedBox(width: 12),
                                _InfoChip(
                                  icon: Icons.timer,
                                  label: 'ETA: $eta',
                                  color: Colors.greenAccent,
                                ),
                              ],
                            ),
                        ],

                        // Response timer (when closed)
                        if (_sos!.status == 'CLOSED') ...[
                          const Divider(color: Colors.grey),
                          const SizedBox(height: 8),
                          if (_sos!.timeToAssign != null)
                            Text(
                              'Time to assign: ${_sos!.timeToAssign!.inMinutes}m ${_sos!.timeToAssign!.inSeconds % 60}s',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          if (_sos!.totalResolutionTime != null)
                            Text(
                              'Total time: ${_sos!.totalResolutionTime!.inMinutes}m ${_sos!.totalResolutionTime!.inSeconds % 60}s',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
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
