import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String userType;
  final double savingsPercentage;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    this.email,
    this.userType = 'selfEmployed',
    this.savingsPercentage = 0.0,
    this.updatedAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: map['email'] as String?,
      userType: map['userType'] as String? ?? 'selfEmployed',
      savingsPercentage: (map['savingsPercentage'] as num?)?.toDouble() ?? 0.0,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  Map<String, dynamic> toMap() {
    return {
      if (email != null) 'email': email,
      'userType': userType,
      'savingsPercentage': savingsPercentage,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }
}
