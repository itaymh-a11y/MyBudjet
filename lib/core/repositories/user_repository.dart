import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import 'firestore_paths.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String userId) =>
      _firestore.doc(FirestorePaths.userDoc(userId));

  Future<UserModel?> getUser(String userId) async {
    final doc = await _userRef(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  Future<void> upsertUser(UserModel user) async {
    await _userRef(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> updateUserSettings({
    required String userId,
    required String userType,
    required double savingsPercentage,
  }) async {
    await _userRef(userId).set(
      {
        'userType': userType,
        'savingsPercentage': savingsPercentage,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
