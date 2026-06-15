import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fixed_monthly_models.dart';
import '../models/gross_deduction_models.dart';
import '../models/student_models.dart';
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
    required bool deductPersonalExpenses,
    required String businessTabName,
    required String businessIconName,
    required int personalCycleStartDay,
    required int businessCycleStartDay,
    required String employeeCompensationType,
    required double employeeFixedMonthlySalary,
    required double employeeHourlyRate,
    required bool selfEmployedManualIncomeEntries,
    required bool selfEmployedManualExpenseEntries,
    required List<FixedGrossDeduction> grossDeductions,
    required List<FixedMonthlyItem> fixedMonthlyItems,
    required List<IncomeSource> incomeSources,
  }) async {
    await _userRef(userId).set(
      {
        'userType': userType,
        'savingsPercentage': savingsPercentage,
        'deductPersonalExpenses': deductPersonalExpenses,
        'businessTabName': businessTabName,
        'businessIconName': businessIconName,
        'personalCycleStartDay': personalCycleStartDay,
        'businessCycleStartDay': businessCycleStartDay,
        'employeeCompensationType': employeeCompensationType,
        'employeeFixedMonthlySalary': employeeFixedMonthlySalary,
        'employeeHourlyRate': employeeHourlyRate,
        'selfEmployedManualIncomeEntries': selfEmployedManualIncomeEntries,
        'selfEmployedManualExpenseEntries': selfEmployedManualExpenseEntries,
        'grossDeductions': fixedGrossDeductionsToFirestore(grossDeductions),
        'fixedMonthlyItems': fixedMonthlyItemsToFirestore(fixedMonthlyItems),
        'incomeSources': incomeSourcesToFirestore(incomeSources),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
