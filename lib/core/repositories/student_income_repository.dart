import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student_models.dart';
import 'firestore_paths.dart';

class StudentIncomeRepository {
  StudentIncomeRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _workLogsRef(String userId) =>
      _firestore.collection(FirestorePaths.incomeWorkLogs(userId));

  CollectionReference<Map<String, dynamic>> _scholarshipsRef(String userId) =>
      _firestore.collection(FirestorePaths.scholarshipEntries(userId));

  Future<List<IncomeWorkLog>> getWorkLogsForRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _workLogsRef(userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date')
        .get();
    return snapshot.docs
        .map((doc) => IncomeWorkLog.fromDoc(doc.id, doc.data()))
        .toList();
  }

  Future<void> addWorkLog(String userId, IncomeWorkLog entry) async {
    final data = entry.toMap();
    data['date'] = Timestamp.fromDate(entry.date);
    data['createdAt'] = Timestamp.fromDate(entry.createdAt);
    await _workLogsRef(userId).add({
      ...data,
      'userId': userId,
    });
  }

  Future<void> deleteWorkLog(String userId, String entryId) async {
    await _workLogsRef(userId).doc(entryId).delete();
  }

  Future<List<ScholarshipEntry>> getAllScholarships(String userId) async {
    final snapshot = await _scholarshipsRef(userId).get();
    final entries = snapshot.docs
        .map((doc) => ScholarshipEntry.fromDoc(doc.id, doc.data()))
        .toList();
    entries.sort(compareScholarshipByExpectedMonth);
    return entries;
  }

  Future<void> addScholarship(String userId, ScholarshipEntry entry) async {
    final data = entry.toMap();
    data['createdAt'] = Timestamp.fromDate(entry.createdAt);
    await _scholarshipsRef(userId).add({
      ...data,
      'userId': userId,
    });
  }

  Future<void> deleteScholarship(String userId, String entryId) async {
    await _scholarshipsRef(userId).doc(entryId).delete();
  }
}
