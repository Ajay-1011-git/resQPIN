import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

/// Premium glassmorphic emergency button with animated glow, press effect,
/// and optional silent-mode indicator.
class EmergencyButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? subtitle;

  const EmergencyButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.subtitle,
  });

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _glowCtrl,
        builder: (context, child) {
          final glowIntensity = 0.08 + _glowCtrl.value * 0.12;
          return AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: widget.color.withValues(
                          alpha: _pressed ? 0.5 : 0.2,
                        ),
                        width: _pressed ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: glowIntensity),
                          blurRadius: 28,
                          spreadRadius: -6,
                        ),
                        if (_pressed)
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.25),
                            blurRadius: 40,
                            spreadRadius: -4,
                          ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Subtle inner gradient
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  widget.color.withValues(alpha: 0.08),
                                  Colors.transparent,
                                  widget.color.withValues(alpha: 0.04),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Content
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon with glowing circle
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      widget.color.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: widget.color.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  widget.icon,
                                  size: 26,
                                  color: widget.color,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.label,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              // Always reserve space for subtitle so all buttons are equal height
                              const SizedBox(height: 3),
                              Text(
                                widget.onLongPress != null
                                    ? (widget.subtitle ?? 'Hold for silent')
                                    : '',
                                style: GoogleFonts.inter(
                                  color: widget.onLongPress != null
                                      ? widget.color.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          );
        },
      ),
    );
  }
}
