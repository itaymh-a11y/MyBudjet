import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/savings_models.dart';
import 'firestore_paths.dart';

class SavingsRepository {
  SavingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _settingsRef(String userId) =>
      _firestore.doc(FirestorePaths.savingsSettingsDoc(userId));

  CollectionReference<Map<String, dynamic>> _monthsRef(String userId) =>
      _firestore.collection(FirestorePaths.savingsMonths(userId));

  static String monthDocId(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  bool _closeEnough(double a, double b) => (a - b).abs() < 0.0001;

  Future<SavingsSettings?> getSettings(String userId) async {
    final doc = await _settingsRef(userId).get();
    if (!doc.exists) return null;
    return SavingsSettings.fromDoc(doc);
  }

  Future<void> upsertSettings(String userId, SavingsSettings settings) async {
    await _settingsRef(userId).set({
      ...settings.toMap(),
      'userId': userId,
    });
  }

  Future<SavingsMonth?> getMonth(
    String userId, {
    required int year,
    required int month,
  }) async {
    final id = monthDocId(year, month);
    final doc = await _monthsRef(userId).doc(id).get();
    if (!doc.exists) return null;
    return SavingsMonth.fromDoc(doc);
  }

  Future<List<SavingsMonth>> getRecentMonths(
    String userId, {
    int limit = 48,
  }) async {
    final snapshot = await _monthsRef(userId).get();
    final list = snapshot.docs.map(SavingsMonth.fromDoc).toList();
    list.sort((a, b) {
      final y = b.year.compareTo(a.year);
      if (y != 0) return y;
      return b.month.compareTo(a.month);
    });
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  Future<void> upsertMonth(String userId, SavingsMonth data) async {
    await _monthsRef(userId).doc(data.id).set({
      ...data.toMap(),
      'userId': userId,
    });
  }

  /// אחרי שמירת נתוני פנסיון – מעדכן יעד חיסכון לחודש זה לפי אחוז נוכחי ונטו.
  /// שומר snapshot; לא משנה רטרואקטיבית חודשים אחרים.
  Future<void> syncFromPensionNet({
    required String userId,
    required int year,
    required int month,
    required double netProfit,
  }) async {
    final settings = await getSettings(userId);
    final percent = settings?.savingsPercent ?? 0;

    final id = monthDocId(year, month);
    final existing = await getMonth(userId, year: year, month: month);

    final netForCalc = netProfit < 0 ? 0.0 : netProfit;
    final target = netForCalc * percent;

    final now = DateTime.now();
    final merged = SavingsMonth(
      id: id,
      userId: userId,
      year: year,
      month: month,
      targetAmount: target,
      percentSnapshot: percent,
      pensionNetSnapshot: netProfit,
      deposited: existing?.deposited ?? false,
      depositedAt: existing?.depositedAt,
      updatedAt: now,
    );
    await upsertMonth(userId, merged);
  }

  Future<void> setDeposited({
    required String userId,
    required int year,
    required int month,
    required bool deposited,
    DateTime? depositedAt,
  }) async {
    final existing = await getMonth(userId, year: year, month: month);
    if (existing == null) return;

    final now = DateTime.now();
    final updated = SavingsMonth(
      id: existing.id,
      userId: userId,
      year: existing.year,
      month: existing.month,
      targetAmount: existing.targetAmount,
      percentSnapshot: existing.percentSnapshot,
      pensionNetSnapshot: existing.pensionNetSnapshot,
      deposited: deposited,
      depositedAt: deposited ? (depositedAt ?? now) : null,
      updatedAt: now,
    );
    await upsertMonth(userId, updated);
  }

  Future<void> syncSuggestedTargetForMonth({
    required String userId,
    required int year,
    required int month,
    required double targetAmount,
    required double percentSnapshot,
    required double baseAmountSnapshot,
  }) async {
    final id = monthDocId(year, month);
    final existing = await getMonth(userId, year: year, month: month);
    final clampedTarget = targetAmount < 0 ? 0.0 : targetAmount;
    final now = DateTime.now();

    if (existing != null &&
        _closeEnough(existing.targetAmount, clampedTarget) &&
        _closeEnough(existing.percentSnapshot, percentSnapshot) &&
        _closeEnough(existing.pensionNetSnapshot, baseAmountSnapshot)) {
      return;
    }

    final merged = SavingsMonth(
      id: id,
      userId: userId,
      year: year,
      month: month,
      targetAmount: clampedTarget,
      percentSnapshot: percentSnapshot,
      pensionNetSnapshot: baseAmountSnapshot,
      deposited: existing?.deposited ?? false,
      depositedAt: existing?.depositedAt,
      updatedAt: now,
    );
    await upsertMonth(userId, merged);
  }
}
