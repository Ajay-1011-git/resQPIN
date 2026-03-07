import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../constants.dart';
import '../services/nlp_classifier_service.dart';

/// Confirmation dialog for voice-detected emergency classification.
///
/// Displays the detected department, category, and severity and asks
/// the user to confirm before creating the SOS. No auto-countdown —
/// the user must explicitly tap "Confirm SOS".
///
/// Returns `true` if confirmed, `false` / `null` if cancelled.
class VoiceEmergencyConfirmationDialog extends StatelessWidget {
  final EmergencyClassification classification;
  final String recognizedText;

  const VoiceEmergencyConfirmationDialog({
    super.key,
    required this.classification,
    required this.recognizedText,
  });

  Color get _typeColor =>
      kSOSTypeColors[classification.type] ?? AppTheme.policeColor;

  IconData get _typeIcon =>
      kSOSTypeIcons[classification.type] ?? Icons.shield_outlined;

  Color get _severityColor =>
      kSeverityColors[classification.severity] ?? AppTheme.accentAmber;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: AlertDialog(
        backgroundColor: AppTheme.surfaceCard.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _typeColor.withValues(alpha: 0.25)),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _typeColor.withValues(alpha: 0.15),
                border: Border.all(
                  color: _typeColor.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Detected Emergency',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Recognized text ─────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    color: AppTheme.textDisabled,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recognizedText,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Classification rows ─────────────────────────────────
            _buildInfoRow(
              icon: Icons.account_balance,
              label: 'Department',
              value: classification.type,
              color: _typeColor,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.category_rounded,
              label: 'Category',
              value: classification.subCategory,
              color: _typeColor,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.speed_rounded,
              label: 'Severity',
              value: classification.severity,
              color: _severityColor,
            ),
          ],
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Confirm SOS button
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _typeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(
              'CONFIRM SOS',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppTheme.textDisabled,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
