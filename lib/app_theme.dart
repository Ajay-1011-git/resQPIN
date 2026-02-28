import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── Background ──────────────────────────────────────────────────────────
  static const Color bgPrimary = Color(0xFF0B1121);
  static const Color bgSecondary = Color(0xFF12122A);
  static const Color surfaceCard = Color(0xFF1E293B);
  static const Color surfaceBorder = Color(0x14FFFFFF); // white 8%

  // ─── Emergency Service Colors ────────────────────────────────────────────
  static const Color policeColor = Color(0xFF1565C0);
  static const Color fireColor = Color(0xFFE53935);
  static const Color ambulanceColor = Color(0xFF43A047);
  static const Color fishermanColor = Color(0xFF00838F);
  static const Color familyColor = Color(0xFF8E24AA);

  // ─── Severity Colors ─────────────────────────────────────────────────────
  static const Color severityLow = Color(0xFF4CAF50);
  static const Color severityMedium = Color(0xFFFFA726);
  static const Color severityHigh = Color(0xFFEF5350);

  // ─── Status Colors ───────────────────────────────────────────────────────
  static const Color statusOpen = Color(0xFFFF9800);
  static const Color statusAssigned = Color(0xFF2196F3);
  static const Color statusClosed = Color(0xFF4CAF50);

  // ─── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFF64748B);

  // ─── Gradients ───────────────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgPrimary, bgSecondary],
  );

  static const LinearGradient policeGradient = LinearGradient(
    colors: [policeColor, Color(0xFF0D47A1)],
  );

  // ─── Frosted Glass Decoration ────────────────────────────────────────────
  static BoxDecoration get glassDecoration => BoxDecoration(
    color: surfaceCard.withValues(alpha: 0.4),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: surfaceBorder),
  );

  static BoxDecoration glassDecorationWithRadius(double radius) =>
      BoxDecoration(
        color: surfaceCard.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: surfaceBorder),
      );

  // ─── Input Decoration ────────────────────────────────────────────────────
  static InputDecoration glassInput({
    required String hint,
    required IconData icon,
    Widget? suffix,
    String? label,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: surfaceCard.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: policeColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: fireColor),
      ),
      prefixIcon: Icon(icon, color: textSecondary),
      suffixIcon: suffix,
      hintText: hint,
      hintStyle: const TextStyle(color: textDisabled),
      labelText: label,
      labelStyle: const TextStyle(
        color: textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  // ─── Status Badge Color Helper ───────────────────────────────────────────
  static Color statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return statusOpen;
      case 'ASSIGNED':
        return statusAssigned;
      case 'CLOSED':
        return statusClosed;
      default:
        return textSecondary;
    }
  }

  // ─── Page Route Transition ───────────────────────────────────────────────
  static Route<T> fadeSlideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  // ─── Theme Data ──────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      brightness: Brightness.dark,
      primaryColor: policeColor,
      scaffoldBackgroundColor: bgPrimary,
      colorScheme: const ColorScheme.dark(
        primary: policeColor,
        secondary: ambulanceColor,
        surface: surfaceCard,
        error: fireColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: surfaceCard.withValues(alpha: 0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: surfaceBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: policeColor,
          foregroundColor: textPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: policeColor, width: 2),
        ),
        hintStyle: const TextStyle(color: textDisabled),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: textPrimary,
          letterSpacing: 3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 1,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: textSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceCard,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── Reusable Widgets ────────────────────────────────────────────────────────

/// Frosted glass card container with blur
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor ?? AppTheme.surfaceBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Pulsing status dot
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({super.key, required this.color, this.size = 8});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.5,
      height: widget.size * 2.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ping ring
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return Container(
                width: widget.size * (1 + _ctrl.value * 1.5),
                height: widget.size * (1 + _ctrl.value * 1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(
                    alpha: 0.4 * (1 - _ctrl.value),
                  ),
                ),
              );
            },
          ),
          // Solid dot
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Liquid background with blurred color blobs
class LiquidBackground extends StatelessWidget {
  final Widget child;
  final Color? accentColor;

  const LiquidBackground({super.key, required this.child, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.policeColor;
    return Container(
      decoration: const BoxDecoration(color: AppTheme.bgPrimary),
      child: Stack(
        children: [
          // Radial gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1),
                  radius: 1.5,
                  colors: [accent.withValues(alpha: 0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          // Top-right blob
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Bottom-left blob
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
              ),
            ),
          ),
          // Actual content
          child,
        ],
      ),
    );
  }
}
