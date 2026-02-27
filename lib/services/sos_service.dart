import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../models/sos_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/digipin_service.dart';

class SOSService {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final Uuid _uuid = const Uuid();

  /// Create a new SOS alert — also fetches family member UIDs for notification
  Future<SOSModel> createSOS({
    required String type,
    required String subCategory,
    required String severity,
    required String createdBy,
    required String createdByName,
    bool silent = false,
  }) async {
    // Get current location
    final Position position = await _locationService.getCurrentPosition();

    // Generate DIGIPIN
    final digipin = DigipinService.generateDigipin(
      position.latitude,
      position.longitude,
    );

    // Fetch linked family members for notification
    List<String> familyUids = [];
    try {
      final familyLink = await _firestoreService.getFamilyLink(createdBy);
      familyUids = familyLink.linkedUsers;
    } catch (_) {}

    // Create SOS model
    final sos = SOSModel(
      sosId: _uuid.v4(),
      type: type,
      subCategory: subCategory,
      severity: severity,
      lat: position.latitude,
      lon: position.longitude,
      digipin: digipin,
      status: 'OPEN',
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: DateTime.now(),
      silent: silent,
      familyMemberUids: familyUids,
    );

    // Save to Firestore
    await _firestoreService.createSOS(sos);

    return sos;
  }

  /// Attend SOS (atomic operation)
  Future<bool> attendSOS({
    required String sosId,
    required String officerId,
    required String officerName,
  }) async {
    return await _firestoreService.attendSOS(
      sosId: sosId,
      officerId: officerId,
      officerName: officerName,
    );
  }

  /// Close SOS
  Future<void> closeSOS(String sosId) async {
    await _firestoreService.closeSOS(sosId);
  }

  /// Generate unique 6-character alphanumeric code for public users
  static String generateUniqueCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    for (int i = 0; i < 6; i++) {
      final index = (random ~/ (i + 1) + i * 7) % chars.length;
      buffer.write(chars[index]);
    }
    return buffer.toString();
  }
}
