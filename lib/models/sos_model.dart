import 'package:cloud_firestore/cloud_firestore.dart';

class SOSModel {
  final String sosId;
  final String type; // POLICE, FIRE, AMBULANCE, FISHERMAN
  final String? subCategory;
  final String severity; // LOW, MEDIUM, HIGH
  final double lat;
  final double lon;
  final String digipin;
  final String status; // OPEN, ASSIGNED, CLOSED
  final String createdBy; // uid of public user
  final String? createdByName;
  final String? assignedOfficerId;
  final String? assignedOfficerName;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? closedAt;
  final bool silent;
  final List<String>
  familyMemberUids; // UIDs of linked family members to notify

  SOSModel({
    required this.sosId,
    required this.type,
    this.subCategory,
    required this.severity,
    required this.lat,
    required this.lon,
    required this.digipin,
    required this.status,
    required this.createdBy,
    this.createdByName,
    this.assignedOfficerId,
    this.assignedOfficerName,
    required this.createdAt,
    this.assignedAt,
    this.closedAt,
    this.silent = false,
    this.familyMemberUids = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'sosId': sosId,
      'type': type,
      'subCategory': subCategory,
      'severity': severity,
      'lat': lat,
      'lon': lon,
      'digipin': digipin,
      'status': status,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'assignedOfficerId': assignedOfficerId,
      'assignedOfficerName': assignedOfficerName,
      'createdAt': Timestamp.fromDate(createdAt),
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'silent': silent,
      'familyMemberUids': familyMemberUids,
    };
  }

  factory SOSModel.fromMap(Map<String, dynamic> map) {
    return SOSModel(
      sosId: map['sosId'] ?? '',
      type: map['type'] ?? '',
      subCategory: map['subCategory'],
      severity: map['severity'] ?? 'MEDIUM',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lon: (map['lon'] ?? 0.0).toDouble(),
      digipin: map['digipin'] ?? '',
      status: map['status'] ?? 'OPEN',
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'],
      assignedOfficerId: map['assignedOfficerId'],
      assignedOfficerName: map['assignedOfficerName'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedAt: (map['assignedAt'] as Timestamp?)?.toDate(),
      closedAt: (map['closedAt'] as Timestamp?)?.toDate(),
      silent: map['silent'] ?? false,
      familyMemberUids: List<String>.from(map['familyMemberUids'] ?? []),
    );
  }

  /// Time from creation to assignment
  Duration? get timeToAssign {
    if (assignedAt == null) return null;
    return assignedAt!.difference(createdAt);
  }

  /// Total resolution time
  Duration? get totalResolutionTime {
    if (closedAt == null) return null;
    return closedAt!.difference(createdAt);
  }
}
