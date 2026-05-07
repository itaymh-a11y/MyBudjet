import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pension_models.dart';
import 'firestore_paths.dart';

class PensionRepository {
  PensionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _monthsRef(String userId) =>
      _firestore.collection(FirestorePaths.pensionMonths(userId));
  CollectionReference<Map<String, dynamic>> _workHoursRef(String userId) =>
      _firestore.collection(FirestorePaths.workHoursEntries(userId));
  CollectionReference<Map<String, dynamic>> _businessIncomeRef(String userId) =>
      _firestore.collection(FirestorePaths.businessIncomeEntries(userId));
  CollectionReference<Map<String, dynamic>> _businessExpenseRef(String userId) =>
      _firestore.collection(FirestorePaths.businessExpenseEntries(userId));

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
    await _monthsRef(userId).doc(monthData.id).set({
      ...monthData.toMap(),
      'userId': userId,
    });
  }

  Future<List<WorkHoursEntry>> getWorkHoursForRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _workHoursRef(userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date')
        .get();
    return snapshot.docs.map(WorkHoursEntry.fromDoc).toList();
  }

  Future<void> addWorkHours(String userId, WorkHoursEntry entry) async {
    await _workHoursRef(userId).add({
      ...entry.toMap(),
      'userId': userId,
    });
  }

  Future<void> deleteWorkHours(String userId, String entryId) async {
    await _workHoursRef(userId).doc(entryId).delete();
  }

  Future<List<BusinessIncomeEntry>> getBusinessIncomeForRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _businessIncomeRef(userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date')
        .get();
    return snapshot.docs.map(BusinessIncomeEntry.fromDoc).toList();
  }

  Future<void> addBusinessIncome(String userId, BusinessIncomeEntry entry) async {
    await _businessIncomeRef(userId).add({
      ...entry.toMap(),
      'userId': userId,
    });
  }

  Future<void> deleteBusinessIncome(String userId, String entryId) async {
    await _businessIncomeRef(userId).doc(entryId).delete();
  }

  Future<List<BusinessExpenseEntry>> getBusinessExpensesForRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _businessExpenseRef(userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date')
        .get();
    return snapshot.docs.map(BusinessExpenseEntry.fromDoc).toList();
  }

  Future<void> addBusinessExpense(
      String userId, BusinessExpenseEntry entry) async {
    await _businessExpenseRef(userId).add({
      ...entry.toMap(),
      'userId': userId,
    });
  }

  Future<void> deleteBusinessExpense(String userId, String entryId) async {
    await _businessExpenseRef(userId).doc(entryId).delete();
  }
}

