import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String userType;
  final double savingsPercentage;
  final bool deductPersonalExpenses;
  final String businessTabName;
  final String businessIconName;
  final int personalCycleStartDay;
  final int businessCycleStartDay;
  final String employeeCompensationType; // 'fixed' | 'hourly'
  final double employeeFixedMonthlySalary;
  final double employeeHourlyRate;
  final bool selfEmployedManualIncomeEntries;
  final bool selfEmployedManualExpenseEntries;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    this.email,
    this.userType = 'selfEmployed',
    this.savingsPercentage = 0.0,
    this.deductPersonalExpenses = false,
    this.businessTabName = 'הכנסות',
    this.businessIconName = 'business',
    this.personalCycleStartDay = 10,
    this.businessCycleStartDay = 1,
    this.employeeCompensationType = 'fixed',
    this.employeeFixedMonthlySalary = 0.0,
    this.employeeHourlyRate = 0.0,
    this.selfEmployedManualIncomeEntries = false,
    this.selfEmployedManualExpenseEntries = false,
    this.updatedAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: map['email'] as String?,
      userType: map['userType'] as String? ?? 'selfEmployed',
      savingsPercentage: (map['savingsPercentage'] as num?)?.toDouble() ?? 0.0,
      deductPersonalExpenses: map['deductPersonalExpenses'] as bool? ?? false,
      businessTabName: map['businessTabName'] as String? ?? 'הכנסות',
      businessIconName: map['businessIconName'] as String? ?? 'business',
      personalCycleStartDay: (map['personalCycleStartDay'] as num?)?.toInt() ?? 10,
      businessCycleStartDay: (map['businessCycleStartDay'] as num?)?.toInt() ?? 1,
      employeeCompensationType:
          map['employeeCompensationType'] as String? ?? 'fixed',
      employeeFixedMonthlySalary:
          (map['employeeFixedMonthlySalary'] as num?)?.toDouble() ?? 0.0,
      employeeHourlyRate: (map['employeeHourlyRate'] as num?)?.toDouble() ?? 0.0,
      selfEmployedManualIncomeEntries:
          map['selfEmployedManualIncomeEntries'] as bool? ?? false,
      selfEmployedManualExpenseEntries:
          map['selfEmployedManualExpenseEntries'] as bool? ?? false,
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
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }
}
