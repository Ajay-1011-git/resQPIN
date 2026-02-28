import 'dart:ui';
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
import '../utils/animations.dart';
import '../widgets/glass_widgets.dart';

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
    // If this officer already attended this alert, skip straight to map view
    if (widget.sos.status == 'ASSIGNED' &&
        widget.sos.assignedOfficerId == widget.officerUser.uid) {
      _attended = true;
      _showMap = true;
    }
    _loadOfficerLocation();
  }

  Future<void> _loadOfficerLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() => _officerPos = LatLng(pos.latitude, pos.longitude));
      }
      // If already attending, start live location updates
      if (_attended) {
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
              height: MediaQuery.of(context).size.height * 0.55,
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
                  // Distance/ETA glass overlay
                  if (_officerPos != null)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 56,
                      left: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.bgPrimary.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: typeColor.withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: typeColor.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  spreadRadius: -2,
                                ),
                              ],
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
                      ),
                    ),
                ],
              ),
            ),

          // ─── Details Section ──────────────────────────────
          Expanded(
            child: LiquidBackground(
              accentColor: typeColor,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_showMap)
                      SizedBox(height: MediaQuery.of(context).padding.top + 56),

                    // Alert Header Card
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 100),
                      child: GlassContainer(
                        glowColor: typeColor,
                        borderColor: typeColor.withValues(alpha: 0.25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        typeColor.withValues(alpha: 0.25),
                                        typeColor.withValues(alpha: 0.08),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: typeColor.withValues(alpha: 0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: typeColor.withValues(alpha: 0.2),
                                        blurRadius: 14,
                                        spreadRadius: -2,
                                      ),
                                    ],
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
                                GlassStatusBadge(
                                  label: widget.sos.severity,
                                  color: severityColor,
                                ),
                              ],
                            ),
                            if (widget.sos.silent) ...[
                              const SizedBox(height: 12),
                              GlassInfoChip(
                                icon: Icons.volume_off,
                                label: 'SILENT — Handle with caution',
                                color: Colors.redAccent,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Details Grid with staggered entrance
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Reported by',
                        value: widget.sos.createdByName ?? 'Unknown',
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 260),
                      child: _DetailRow(
                        icon: Icons.access_time,
                        label: 'Created at',
                        value: DateFormat(
                          'dd MMM yyyy, HH:mm:ss',
                        ).format(widget.sos.createdAt),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 320),
                      child: _DetailRow(
                        icon: Icons.pin_drop,
                        label: 'DIGIPIN',
                        value: widget.sos.digipin,
                        isCode: true,
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 380),
                      child: _DetailRow(
                        icon: Icons.place,
                        label: 'Coordinates',
                        value:
                            '${widget.sos.lat.toStringAsFixed(5)}, ${widget.sos.lon.toStringAsFixed(5)}',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Action Buttons ─────────────────────────
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 450),
                      child: Column(
                        children: [
                          if (!_attended) ...[
                            GradientLoadingButton(
                              label: _isAttending ? 'ASSIGNING...' : 'ATTEND',
                              isLoading: _isAttending,
                              icon: Icons.check_circle_outline,
                              color: typeColor,
                              onPressed: _isAttending ? null : _attendAlert,
                            ),
                          ] else ...[
                            if (!_showMap)
                              GradientLoadingButton(
                                label: 'SHOW MAP',
                                isLoading: false,
                                icon: Icons.map,
                                color: AppTheme.policeColor,
                                onPressed: () =>
                                    setState(() => _showMap = true),
                              ),
                            const SizedBox(height: 12),
                            _GlassOutlineButton(
                              label: 'MARK RESOLVED',
                              icon: Icons.task_alt,
                              color: AppTheme.ambulanceColor,
                              onPressed: _closeAlert,
                            ),
                          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.surfaceBorder.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentCyan.withValues(alpha: 0.1),
              border: Border.all(
                color: AppTheme.accentCyan.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, size: 16, color: AppTheme.accentCyan),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 3),
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

/// Glass-styled outline button with press animation.
class _GlassOutlineButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _GlassOutlineButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_GlassOutlineButton> createState() => _GlassOutlineButtonState();
}

class _GlassOutlineButtonState extends State<_GlassOutlineButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _pressed
                ? widget.color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withValues(alpha: _pressed ? 0.8 : 0.5),
              width: 1.5,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 22, color: widget.color),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
