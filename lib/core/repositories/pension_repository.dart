import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pension_models.dart';
import 'firestore_paths.dart';

class PensionRepository {
  PensionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _monthsRef(String userId) =>
      _firestore.collection(FirestorePaths.pensionMonths(userId));

  Future<PensionMonth?> getMonth({
    required String userId,
    required int year,
    required int month,
  }) async {
    final snapshot = await _monthsRef(userId)
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return PensionMonth.fromDoc(snapshot.docs.first);
  }

  Future<List<PensionMonth>> getRecentMonths(String userId,
      {int limit = 12}) async {
    final snapshot = await _monthsRef(userId)
        .orderBy('year', descending: true)
        .orderBy('month', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(PensionMonth.fromDoc).toList();
  }

  Future<void> upsertMonth(String userId, PensionMonth monthData) async {
    await _monthsRef(userId).doc(monthData.id).set(monthData.toMap());
  }
}

