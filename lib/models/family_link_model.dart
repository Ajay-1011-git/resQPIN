class FamilyLinkModel {
  final String uid;
  final List<String> linkedUsers;
  final List<String> pendingRequests;

  FamilyLinkModel({
    required this.uid,
    required this.linkedUsers,
    required this.pendingRequests,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'linkedUsers': linkedUsers,
      'pendingRequests': pendingRequests,
    };
  }

  factory FamilyLinkModel.fromMap(Map<String, dynamic> map) {
    return FamilyLinkModel(
      uid: map['uid'] ?? '',
      linkedUsers: List<String>.from(map['linkedUsers'] ?? []),
      pendingRequests: List<String>.from(map['pendingRequests'] ?? []),
    );
  }
}
