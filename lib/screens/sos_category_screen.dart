import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../constants.dart';

/// Screen for selecting SOS sub-category and severity.
/// Returns a Map with 'subCategory' and 'severity' on selection.
class SOSCategoryScreen extends StatefulWidget {
  final String sosType;

  const SOSCategoryScreen({super.key, required this.sosType});

  @override
  State<SOSCategoryScreen> createState() => _SOSCategoryScreenState();
}

class _SOSCategoryScreenState extends State<SOSCategoryScreen> {
  String _selectedSeverity = 'MEDIUM';

  List<String> get _subcategories =>
      kSubcategories[widget.sosType] ?? ['General Emergency'];

  @override
  Widget build(BuildContext context) {
    final typeColor = kSOSTypeColors[widget.sosType] ?? Colors.blueAccent;
    final typeIcon = kSOSTypeIcons[widget.sosType] ?? Icons.emergency;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          '${widget.sosType} Alert',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: LiquidBackground(
        accentColor: typeColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ─── Header ────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: typeColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: typeColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Category',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'What type of emergency?',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ─── Severity Selection ────────────────────────────
                Text(
                  'SEVERITY LEVEL',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white54,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: kSeverityLevels.map((level) {
                    final isSelected = level == _selectedSeverity;
                    final color = kSeverityColors[level]!;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedSeverity = level),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.15)
                                : AppTheme.surfaceCard.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? color.withValues(alpha: 0.6)
                                  : AppTheme.surfaceBorder,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.2),
                                      blurRadius: 16,
                                      spreadRadius: -4,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              level,
                              style: GoogleFonts.inter(
                                color: isSelected
                                    ? color
                                    : AppTheme.textDisabled,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // ─── Sub-categories ────────────────────────────────
                Text(
                  'EMERGENCY TYPE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white54,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _subcategories.length,
                    itemBuilder: (context, i) {
                      final sub = _subcategories[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context, {
                            'subCategory': sub,
                            'severity': _selectedSeverity,
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceCard.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.surfaceBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: typeColor.withValues(alpha: 0.15),
                                ),
                                child: Icon(
                                  typeIcon,
                                  color: typeColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  sub,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: AppTheme.textDisabled,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
