import 'package:cloud_firestore/cloud_firestore.dart';

class OfficerLocationModel {
  final String officerId;
  final double lat;
  final double lon;
  final DateTime updatedAt;

  OfficerLocationModel({
    required this.officerId,
    required this.lat,
    required this.lon,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'officerId': officerId,
      'lat': lat,
      'lon': lon,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory OfficerLocationModel.fromMap(Map<String, dynamic> map) {
    return OfficerLocationModel(
      officerId: map['officerId'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lon: (map['lon'] ?? 0.0).toDouble(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
