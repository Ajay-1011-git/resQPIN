import 'package:flutter/material.dart';

// ─── Allowed Officer Email Domains ───────────────────────────────────────────
const List<String> kAllowedOfficerDomains = [
  'police.gov.in',
  'health.gov.in',
  'fireservice.gov.in',
  'coastguard.gov.in',
];

// ─── Domain → Department Mapping ─────────────────────────────────────────────
const Map<String, String> kDomainToDepartment = {
  'police.gov.in': 'POLICE',
  'health.gov.in': 'AMBULANCE',
  'fireservice.gov.in': 'FIRE',
  'coastguard.gov.in': 'COASTAL',
};

// ─── SOS Types ───────────────────────────────────────────────────────────────
const List<String> kSOSTypes = ['POLICE', 'FIRE', 'AMBULANCE', 'FISHERMAN'];

// ─── Department → SOS Type Mapping (for officers) ────────────────────────────
const Map<String, String> kDepartmentToSOSType = {
  'POLICE': 'POLICE',
  'AMBULANCE': 'AMBULANCE',
  'FIRE': 'FIRE',
  'COASTAL': 'FISHERMAN',
};

// ─── Subcategories ───────────────────────────────────────────────────────────
const Map<String, List<String>> kSubcategories = {
  'AMBULANCE': [
    'Accident',
    'Heart attack',
    'Unconscious',
    'Pregnancy emergency',
  ],
  'FIRE': ['House fire', 'Electrical fire', 'Gas leak'],
  'POLICE': ['Theft', 'Violence', 'Suspicious activity'],
  'FISHERMAN': [
    'Engine failure',
    'Lost navigation',
    'Medical emergency at sea',
  ],
};

// ─── Severity Levels ─────────────────────────────────────────────────────────
const List<String> kSeverityLevels = ['LOW', 'MEDIUM', 'HIGH'];

const Map<String, Color> kSeverityColors = {
  'LOW': Color(0xFF4CAF50),
  'MEDIUM': Color(0xFFFFA726),
  'HIGH': Color(0xFFEF5350),
};

// ─── SOS Status ──────────────────────────────────────────────────────────────
const List<String> kSOSStatuses = ['OPEN', 'ASSIGNED', 'CLOSED'];

// ─── Icon Mapping ────────────────────────────────────────────────────────────
const Map<String, IconData> kSOSTypeIcons = {
  'POLICE': Icons.local_police,
  'FIRE': Icons.local_fire_department,
  'AMBULANCE': Icons.local_hospital,
  'FISHERMAN': Icons.sailing,
};

const Map<String, Color> kSOSTypeColors = {
  'POLICE': Color(0xFF1565C0),
  'FIRE': Color(0xFFE53935),
  'AMBULANCE': Color(0xFF43A047),
  'FISHERMAN': Color(0xFF00838F),
};

// ─── Domain validation helpers ───────────────────────────────────────────────
bool isOfficialEmail(String email) {
  final domain = email.split('@').last.toLowerCase().trim();
  return kAllowedOfficerDomains.contains(domain);
}

String? getDepartmentFromEmail(String email) {
  final domain = email.split('@').last.toLowerCase().trim();
  return kDomainToDepartment[domain];
}
