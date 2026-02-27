import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final int age;
  final String gender;
  final String email;
  final String phone;
  final String role; // 'PUBLIC' or 'OFFICER'
  final String?
  department; // Only for OFFICER: POLICE, AMBULANCE, FIRE, COASTAL
  final String? uniqueCode; // Only for PUBLIC: 6-char alphanumeric
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.age,
    required this.gender,
    required this.email,
    required this.phone,
    required this.role,
    this.department,
    this.uniqueCode,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'age': age,
      'gender': gender,
      'email': email,
      'phone': phone,
      'role': role,
      'department': department,
      'uniqueCode': uniqueCode,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'PUBLIC',
      department: map['department'],
      uniqueCode: map['uniqueCode'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
