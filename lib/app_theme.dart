import 'dart:ui';
import 'dart:math' as math;
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

  // ─── Accent / Glow Colors ───────────────────────────────────────────────
  static const Color accentCyan = Color(0xFF0EA5E9);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentAmber = Color(0xFFF59E0B);

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

  static const LinearGradient fireGradient = LinearGradient(
    colors: [Color(0xFFFF5722), fireColor],
  );

  static const LinearGradient ambulanceGradient = LinearGradient(
    colors: [Color(0xFF66BB6A), ambulanceColor],
  );

  static const LinearGradient familyGradient = LinearGradient(
    colors: [Color(0xFFAB47BC), familyColor],
  );

  static const LinearGradient fishermanGradient = LinearGradient(
    colors: [accentCyan, fishermanColor],
  );

  static LinearGradient shimmerGradient(Color base) => LinearGradient(
    colors: [
      base.withValues(alpha: 0.0),
      base.withValues(alpha: 0.15),
      base.withValues(alpha: 0.0),
    ],
    stops: const [0.0, 0.5, 1.0],
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

  static BoxDecoration glowGlassDecoration({
    required Color glowColor,
    double radius = 20,
    double glowOpacity = 0.2,
    double blurRadius = 30,
  }) =>
      BoxDecoration(
        color: surfaceCard.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: glowColor.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: glowOpacity),
            blurRadius: blurRadius,
            spreadRadius: -8,
          ),
        ],
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

  // ─── Page Route Transition (Smooth spring-like) ──────────────────────────
  static Route<T> fadeSlideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutExpo,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Scale + fade transition for modals / dialogs
  static Route<T> scaleRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
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

/// Frosted glass card container with blur and optional glow
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? glowColor;
  final double blur;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.borderColor,
    this.glowColor,
    this.blur = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor ?? AppTheme.surfaceBorder),
            boxShadow: glowColor != null
                ? [
                    BoxShadow(
                      color: glowColor!.withValues(alpha: 0.15),
                      blurRadius: 24,
                      spreadRadius: -6,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Heavy frosted glass panel for bottom sheets / overlays
class HeavyGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const HeavyGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 32,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(borderRadius),
        topRight: Radius.circular(borderRadius),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF111921).withValues(alpha: 0.85),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(borderRadius),
              topRight: Radius.circular(borderRadius),
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
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

/// Liquid background with animated floating blurred color blobs
class LiquidBackground extends StatefulWidget {
  final Widget child;
  final Color? accentColor;

  const LiquidBackground({super.key, required this.child, this.accentColor});

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 8),
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
    final accent = widget.accentColor ?? AppTheme.policeColor;
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
          // Animated floating blob - top right
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final dx = math.sin(_ctrl.value * 2 * math.pi) * 20;
              final dy = math.cos(_ctrl.value * 2 * math.pi) * 15;
              return Positioned(
                top: -80 + dy,
                right: -80 + dx,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.12),
                        accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Animated floating blob - bottom left
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final dx = math.cos(_ctrl.value * 2 * math.pi + 1) * 25;
              final dy = math.sin(_ctrl.value * 2 * math.pi + 1) * 20;
              return Positioned(
                bottom: -60 + dy,
                left: -60 + dx,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        const Color(0xFF7C3AED).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Third floating blob - center right (subtle)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final dx =
                  math.sin(_ctrl.value * 2 * math.pi + math.pi / 3) * 18;
              final dy =
                  math.cos(_ctrl.value * 2 * math.pi + math.pi / 3) * 12;
              return Positioned(
                top: MediaQuery.of(context).size.height * 0.4 + dy,
                right: -40 + dx,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.06),
                        accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Actual content
          widget.child,
        ],
      ),
    );
  }
}
