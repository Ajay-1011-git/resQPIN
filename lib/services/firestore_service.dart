import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/sos_model.dart';
import '../models/officer_location_model.dart';
import '../models/family_link_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── USER OPERATIONS ─────────────────────────────────────────────────────

  /// Create user document
  Future<void> createUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  /// Get user by UID
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  /// Get user by unique code (for family linking)
  Future<UserModel?> getUserByCode(String code) async {
    final query = await _db
        .collection('users')
        .where('uniqueCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return UserModel.fromMap(query.docs.first.data());
    }
    return null;
  }

  // ─── SOS OPERATIONS ──────────────────────────────────────────────────────

  /// Create SOS alert
  Future<void> createSOS(SOSModel sos) async {
    await _db.collection('sos').doc(sos.sosId).set(sos.toMap());
  }

  /// Stream SOS alerts for a public user
  /// Note: No orderBy to avoid needing a composite index.
  /// Sorting is done client-side.
  Stream<List<SOSModel>> streamUserSOS(String uid) {
    return _db
        .collection('sos')
        .where('createdBy', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => SOSModel.fromMap(d.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Stream a single SOS alert by ID
  Stream<SOSModel?> streamSOS(String sosId) {
    return _db.collection('sos').doc(sosId).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        return SOSModel.fromMap(snap.data()!);
      }
      return null;
    });
  }

  /// Stream OPEN SOS alerts by type (for officer dashboard)
  /// Uses only equality filters — no orderBy to avoid composite index requirement.
  /// Sorting is done client-side.
  Stream<List<SOSModel>> streamOpenSOSByType(String sosType) {
    return _db
        .collection('sos')
        .where('status', isEqualTo: 'OPEN')
        .where('type', isEqualTo: sosType)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => SOSModel.fromMap(d.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Atomic attend — using Firestore transaction to prevent duplicate assignment
  ///
  /// Stream ASSIGNED SOS alerts for a specific officer (for re-login visibility)
  Stream<List<SOSModel>> streamAssignedSOSByOfficer(String officerId) {
    return _db
        .collection('sos')
        .where('assignedOfficerId', isEqualTo: officerId)
        .where('status', isEqualTo: 'ASSIGNED')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => SOSModel.fromMap(d.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Atomic attend — using Firestore transaction to prevent duplicate assignment
  Future<bool> attendSOS({
    required String sosId,
    required String officerId,
    required String officerName,
  }) async {
    final sosRef = _db.collection('sos').doc(sosId);
    return _db.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(sosRef);
      if (!snapshot.exists) return false;

      final data = snapshot.data()!;
      if (data['status'] != 'OPEN') {
        return false; // Already assigned
      }

      transaction.update(sosRef, {
        'status': 'ASSIGNED',
        'assignedOfficerId': officerId,
        'assignedOfficerName': officerName,
        'assignedAt': Timestamp.now(),
      });
      return true;
    });
  }

  /// Close SOS alert
  Future<void> closeSOS(String sosId) async {
    await _db.collection('sos').doc(sosId).update({
      'status': 'CLOSED',
      'closedAt': Timestamp.now(),
    });
  }

  // ─── OFFICER LOCATION ────────────────────────────────────────────────────

  /// Update officer live location
  Future<void> updateOfficerLocation(OfficerLocationModel location) async {
    await _db
        .collection('officer_locations')
        .doc(location.officerId)
        .set(location.toMap());
  }

  /// Stream officer location
  Stream<OfficerLocationModel?> streamOfficerLocation(String officerId) {
    return _db.collection('officer_locations').doc(officerId).snapshots().map((
      snap,
    ) {
      if (snap.exists && snap.data() != null) {
        return OfficerLocationModel.fromMap(snap.data()!);
      }
      return null;
    });
  }

  // ─── FAMILY LINKS ────────────────────────────────────────────────────────

  /// Get or create family link
  Future<FamilyLinkModel> getFamilyLink(String uid) async {
    final doc = await _db.collection('family_links').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return FamilyLinkModel.fromMap(doc.data()!);
    }
    final newLink = FamilyLinkModel(
      uid: uid,
      linkedUsers: [],
      pendingRequests: [],
    );
    await _db.collection('family_links').doc(uid).set(newLink.toMap());
    return newLink;
  }

  /// Send family link request
  Future<void> sendFamilyRequest({
    required String fromUid,
    required String toUid,
  }) async {
    await _db.collection('family_links').doc(toUid).update({
      'pendingRequests': FieldValue.arrayUnion([fromUid]),
    });
  }

  /// Accept family link request
  Future<void> acceptFamilyRequest({
    required String myUid,
    required String requesterUid,
  }) async {
    final batch = _db.batch();
    final myRef = _db.collection('family_links').doc(myUid);
    final theirRef = _db.collection('family_links').doc(requesterUid);

    batch.update(myRef, {
      'pendingRequests': FieldValue.arrayRemove([requesterUid]),
      'linkedUsers': FieldValue.arrayUnion([requesterUid]),
    });
    batch.update(theirRef, {
      'linkedUsers': FieldValue.arrayUnion([myUid]),
    });

    await batch.commit();
  }

  /// Stream family link
  Stream<FamilyLinkModel?> streamFamilyLink(String uid) {
    return _db.collection('family_links').doc(uid).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        return FamilyLinkModel.fromMap(snap.data()!);
      }
      return null;
    });
  }
}
