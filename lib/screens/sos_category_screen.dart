import 'package:flutter/material.dart';
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
      appBar: AppBar(title: Text('${widget.sosType} Alert')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 32),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Category',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'What type of emergency?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ─── Severity Selection ────────────────────────────────
            Text(
              'Severity Level',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 16),
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
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.2)
                            : const Color(0xFF2A2A3C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          level,
                          style: TextStyle(
                            color: isSelected ? color : Colors.grey,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // ─── Sub-categories ────────────────────────────────────
            Text(
              'Emergency Type',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _subcategories.length,
                itemBuilder: (context, i) {
                  final sub = _subcategories[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: const Color(0xFF2A2A3C),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(context, {
                            'subCategory': sub,
                            'severity': _selectedSeverity,
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  sub,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
