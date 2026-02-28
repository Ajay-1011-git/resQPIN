import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../app_theme.dart';
import '../models/sos_model.dart';
import '../models/user_model.dart';
import '../models/officer_location_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../constants.dart';

class AlertDetailScreen extends StatefulWidget {
  final SOSModel sos;
  final UserModel officerUser;

  const AlertDetailScreen({
    super.key,
    required this.sos,
    required this.officerUser,
  });

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  bool _isAttending = false;
  bool _attended = false;
  bool _showMap = false;
  LatLng? _officerPos;

  @override
  void initState() {
    super.initState();
    _loadOfficerLocation();
  }

  Future<void> _loadOfficerLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() => _officerPos = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  Future<void> _attendAlert() async {
    setState(() => _isAttending = true);
    try {
      final success = await _firestoreService.attendSOS(
        sosId: widget.sos.sosId,
        officerId: widget.officerUser.uid,
        officerName: widget.officerUser.name,
      );
      if (!mounted) return;
      if (success) {
        setState(() {
          _attended = true;
          _showMap = true;
        });
        _locationService.startLocationUpdates(
          onLocationChanged: (position) {
            if (mounted) {
              setState(
                () =>
                    _officerPos = LatLng(position.latitude, position.longitude),
              );
            }
            _firestoreService.updateOfficerLocation(
              OfficerLocationModel(
                officerId: widget.officerUser.uid,
                lat: position.latitude,
                lon: position.longitude,
                updatedAt: DateTime.now(),
              ),
            );
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert assigned to you!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Already assigned to another officer.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAttending = false);
    }
  }

  Future<void> _closeAlert() async {
    try {
      await _firestoreService.closeSOS(widget.sos.sosId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert closed.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    markers.add(
      Marker(
        markerId: const MarkerId('sos_location'),
        position: LatLng(widget.sos.lat, widget.sos.lon),
        infoWindow: InfoWindow(
          title: 'SOS Location',
          snippet: widget.sos.subCategory ?? widget.sos.type,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
    if (_officerPos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('officer_location'),
          position: _officerPos!,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _buildRoute() {
    if (_officerPos == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_officerPos!, LatLng(widget.sos.lat, widget.sos.lon)],
        color: AppTheme.policeColor,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  String _getDistanceText() {
    if (_officerPos == null) return '';
    final d = LocationService.calculateDistance(
      _officerPos!.latitude,
      _officerPos!.longitude,
      widget.sos.lat,
      widget.sos.lon,
    );
    return '${LocationService.formatDistance(d)} • ETA ${LocationService.estimateETA(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = kSOSTypeColors[widget.sos.type] ?? Colors.blueAccent;
    final severityColor =
        kSeverityColors[widget.sos.severity] ?? Colors.orangeAccent;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Alert Details',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // ─── In-App Map (shown after ATTEND) ─────────────
          if (_showMap)
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(widget.sos.lat, widget.sos.lon),
                      zoom: 14,
                    ),
                    markers: _buildMarkers(),
                    polylines: _buildRoute(),
                    onMapCreated: (controller) {
                      if (_officerPos != null) {
                        final bounds = LatLngBounds(
                          southwest: LatLng(
                            widget.sos.lat < _officerPos!.latitude
                                ? widget.sos.lat
                                : _officerPos!.latitude,
                            widget.sos.lon < _officerPos!.longitude
                                ? widget.sos.lon
                                : _officerPos!.longitude,
                          ),
                          northeast: LatLng(
                            widget.sos.lat > _officerPos!.latitude
                                ? widget.sos.lat
                                : _officerPos!.latitude,
                            widget.sos.lon > _officerPos!.longitude
                                ? widget.sos.lon
                                : _officerPos!.longitude,
                          ),
                        );
                        controller.animateCamera(
                          CameraUpdate.newLatLngBounds(bounds, 60),
                        );
                      }
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapType: MapType.normal,
                  ),
                  // Distance/ETA overlay
                  if (_officerPos != null)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 56,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.bgPrimary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: typeColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_car,
                              size: 16,
                              color: typeColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getDistanceText(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ─── Details Section ──────────────────────────────
          Expanded(
            child: Container(
              color: AppTheme.bgPrimary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_showMap)
                      SizedBox(height: MediaQuery.of(context).padding.top + 56),

                    // Alert Header Card
                    GlassContainer(
                      borderColor: typeColor.withValues(alpha: 0.2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: typeColor.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: typeColor.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  kSOSTypeIcons[widget.sos.type] ??
                                      Icons.emergency,
                                  color: typeColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.sos.type,
                                      style: GoogleFonts.inter(
                                        color: typeColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    if (widget.sos.subCategory != null)
                                      Text(
                                        widget.sos.subCategory!,
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: severityColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.sos.severity,
                                  style: GoogleFonts.inter(
                                    color: severityColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.sos.silent) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.volume_off,
                                    size: 14,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'SILENT ALERT — Handle with caution',
                                    style: GoogleFonts.inter(
                                      color: Colors.redAccent,
                                      fontSize: 11,
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
                    const SizedBox(height: 16),

                    // Details Grid
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Reported by',
                      value: widget.sos.createdByName ?? 'Unknown',
                    ),
                    _DetailRow(
                      icon: Icons.access_time,
                      label: 'Created at',
                      value: DateFormat(
                        'dd MMM yyyy, HH:mm:ss',
                      ).format(widget.sos.createdAt),
                    ),
                    _DetailRow(
                      icon: Icons.pin_drop,
                      label: 'DIGIPIN',
                      value: widget.sos.digipin,
                      isCode: true,
                    ),
                    _DetailRow(
                      icon: Icons.place,
                      label: 'Coordinates',
                      value:
                          '${widget.sos.lat.toStringAsFixed(5)}, ${widget.sos.lon.toStringAsFixed(5)}',
                    ),
                    const SizedBox(height: 24),

                    // ─── Action Buttons ─────────────────────────
                    if (!_attended) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isAttending ? null : _attendAlert,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: typeColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isAttending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  size: 22,
                                ),
                          label: Text(
                            _isAttending ? 'ASSIGNING...' : 'ATTEND',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      if (!_showMap)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () => setState(() => _showMap = true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.policeColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.map, size: 22),
                            label: Text(
                              'SHOW MAP',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _closeAlert,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.ambulanceColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            Icons.task_alt,
                            size: 22,
                            color: AppTheme.ambulanceColor,
                          ),
                          label: Text(
                            'MARK RESOLVED',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: AppTheme.ambulanceColor,
                            ),
                          ),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isCode;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: AppTheme.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: isCode
                      ? GoogleFonts.robotoMono(
                          color: AppTheme.policeColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        )
                      : GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
