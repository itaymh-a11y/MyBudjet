import 'package:flutter/material.dart';

import 'fixed_monthly_models.dart';
import 'gross_deduction_models.dart';

class IncomeSource {
  final String id;
  final String name;
  final String iconName;
  /// `hourly` | `fixedMonthly`
  final String payType;
  final double hourlyRate;
  final double fixedMonthlyAmount;
  final bool isActive;

  const IncomeSource({
    required this.id,
    required this.name,
    this.iconName = 'work',
    this.payType = 'hourly',
    this.hourlyRate = 0,
    this.fixedMonthlyAmount = 0,
    this.isActive = true,
  });

  bool get isHourly => payType == 'hourly';
  bool get isFixedMonthly => payType == 'fixedMonthly';

  factory IncomeSource.fromMap(Map<String, dynamic> map) {
    return IncomeSource(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      iconName: map['iconName'] as String? ?? 'work',
      payType: map['payType'] as String? ?? 'hourly',
      hourlyRate: (map['hourlyRate'] as num?)?.toDouble() ?? 0,
      fixedMonthlyAmount: (map['fixedMonthlyAmount'] as num?)?.toDouble() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'payType': payType,
      'hourlyRate': hourlyRate,
      'fixedMonthlyAmount': fixedMonthlyAmount,
      'isActive': isActive,
    };
  }
}

class IncomeWorkLog {
  final String id;
  final String userId;
  final String sourceId;
  final DateTime date;
  final double hours;
  final double rateSnapshot;
  final double amount;
  final DateTime createdAt;

  const IncomeWorkLog({
    required this.id,
    required this.userId,
    required this.sourceId,
    required this.date,
    required this.hours,
    required this.rateSnapshot,
    required this.amount,
    required this.createdAt,
  });

  factory IncomeWorkLog.fromDoc(String id, Map<String, dynamic> data) {
    return IncomeWorkLog(
      id: id,
      userId: data['userId'] as String? ?? '',
      sourceId: data['sourceId'] as String? ?? '',
      date: (data['date'] as dynamic)?.toDate() ?? DateTime.now(),
      hours: (data['hours'] as num?)?.toDouble() ?? 0,
      rateSnapshot: (data['rateSnapshot'] as num?)?.toDouble() ?? 0,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sourceId': sourceId,
      'date': date,
      'hours': hours,
      'rateSnapshot': rateSnapshot,
      'amount': amount,
      'createdAt': createdAt,
    };
  }
}

const hebrewMonthNames = [
  '',
  'ינואר',
  'פברואר',
  'מרץ',
  'אפריל',
  'מאי',
  'יוני',
  'יולי',
  'אוגוסט',
  'ספטמבר',
  'אוקטובר',
  'נובמבר',
  'דצמבר',
];

String formatScholarshipExpectedMonth(int year, int month) {
  if (month < 1 || month > 12) return '$month/$year';
  return '${hebrewMonthNames[month]} $year';
}

int compareScholarshipByExpectedMonth(ScholarshipEntry a, ScholarshipEntry b) {
  if (a.expectedYear != b.expectedYear) {
    return a.expectedYear.compareTo(b.expectedYear);
  }
  return a.expectedMonth.compareTo(b.expectedMonth);
}

class ScholarshipEntry {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final int expectedYear;
  final int expectedMonth;
  /// `entitlement` (זכאות) | `volunteer` (התנדבותית) | null
  final String? classification;
  final double? requiredVolunteerHours;
  final DateTime createdAt;

  const ScholarshipEntry({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.expectedYear,
    required this.expectedMonth,
    this.classification,
    this.requiredVolunteerHours,
    required this.createdAt,
  });

  String get expectedMonthLabel =>
      formatScholarshipExpectedMonth(expectedYear, expectedMonth);

  bool get isVolunteer => classification == 'volunteer';
  bool get isEntitlement => classification == 'entitlement';

  double? get volunteerHourlyValue {
    if (!isVolunteer ||
        requiredVolunteerHours == null ||
        requiredVolunteerHours! <= 0) {
      return null;
    }
    return amount / requiredVolunteerHours!;
  }

  factory ScholarshipEntry.fromDoc(String id, Map<String, dynamic> data) {
    DateTime? legacyDate;
    final legacyRaw = data['date'];
    if (legacyRaw != null) {
      legacyDate = (legacyRaw as dynamic).toDate() as DateTime;
    }
    return ScholarshipEntry(
      id: id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      expectedYear: (data['expectedYear'] as num?)?.toInt() ??
          legacyDate?.year ??
          DateTime.now().year,
      expectedMonth: (data['expectedMonth'] as num?)?.toInt() ??
          legacyDate?.month ??
          DateTime.now().month,
      classification: data['classification'] as String?,
      requiredVolunteerHours:
          (data['requiredVolunteerHours'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'amount': amount,
      'expectedYear': expectedYear,
      'expectedMonth': expectedMonth,
      if (classification != null) 'classification': classification,
      if (requiredVolunteerHours != null)
        'requiredVolunteerHours': requiredVolunteerHours,
      'createdAt': createdAt,
    };
  }
}

String? scholarshipClassificationLabel(String? classification) {
  switch (classification) {
    case 'entitlement':
      return 'זכאות';
    case 'volunteer':
      return 'התנדבותית';
    default:
      return null;
  }
}

class IncomeSourceMonthSnapshot {
  final String sourceId;
  final String name;
  final double hours;
  final double amount;

  const IncomeSourceMonthSnapshot({
    required this.sourceId,
    required this.name,
    required this.hours,
    required this.amount,
  });

  factory IncomeSourceMonthSnapshot.fromMap(Map<String, dynamic> map) {
    return IncomeSourceMonthSnapshot(
      sourceId: map['sourceId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      hours: (map['hours'] as num?)?.toDouble() ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sourceId': sourceId,
      'name': name,
      'hours': hours,
      'amount': amount,
    };
  }
}

class StudentWorkMonthTotals {
  final double grossBase;
  final double gross;
  final double totalDeductions;
  final double totalExpenses;
  final double net;
  final List<IncomeSourceMonthSnapshot> sourceSnapshots;
  final List<GrossDeductionSnapshot> deductionSnapshots;
  final List<FixedMonthlySnapshot> fixedMonthlySnapshots;
  final double totalFixedAdditions;
  final double totalFixedExpenses;

  const StudentWorkMonthTotals({
    required this.grossBase,
    required this.gross,
    required this.totalDeductions,
    required this.totalExpenses,
    required this.net,
    required this.sourceSnapshots,
    required this.deductionSnapshots,
    required this.fixedMonthlySnapshots,
    required this.totalFixedAdditions,
    required this.totalFixedExpenses,
  });
}

List<IncomeSource> incomeSourcesFromFirestore(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => IncomeSource.fromMap(Map<String, dynamic>.from(item)))
      .where((source) => source.id.isNotEmpty && source.name.trim().isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> incomeSourcesToFirestore(List<IncomeSource> sources) {
  return sources.map((source) => source.toMap()).toList();
}

List<IncomeSourceMonthSnapshot> incomeSourceSnapshotsFromFirestore(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (item) =>
            IncomeSourceMonthSnapshot.fromMap(Map<String, dynamic>.from(item)),
      )
      .toList();
}

IconData incomeSourceIconFromName(String? name) {
  switch (name) {
    case 'child_care':
      return Icons.child_care;
    case 'restaurant':
      return Icons.restaurant;
    case 'school':
      return Icons.school;
    case 'local_cafe':
      return Icons.local_cafe;
    case 'directions_car':
      return Icons.directions_car;
    case 'store':
      return Icons.store;
    case 'fitness':
      return Icons.fitness_center;
    default:
      return Icons.work_outline;
  }
}

const studentIncomeSourceIcons = <({String id, String label, IconData icon})>[
  (id: 'work', label: 'עבודה', icon: Icons.work_outline),
  (id: 'child_care', label: 'בייביסיטר', icon: Icons.child_care),
  (id: 'school', label: 'חונכות', icon: Icons.school),
  (id: 'restaurant', label: 'מסעדה', icon: Icons.restaurant),
  (id: 'local_cafe', label: 'בית קפה', icon: Icons.local_cafe),
  (id: 'store', label: 'חנות', icon: Icons.store),
  (id: 'fitness', label: 'ספורט', icon: Icons.fitness_center),
  (id: 'directions_car', label: 'נסיעות', icon: Icons.directions_car),
];

StudentWorkMonthTotals computeStudentWorkMonth({
  required List<IncomeSource> sources,
  required List<IncomeWorkLog> logs,
  required List<FixedGrossDeduction> deductions,
  required List<FixedMonthlyItem> fixedItems,
}) {
  final activeSources =
      sources.where((source) => source.isActive).toList(growable: false);
  final snapshots = <IncomeSourceMonthSnapshot>[];
  var grossBase = 0.0;

  for (final source in activeSources) {
    final sourceLogs = logs.where((log) => log.sourceId == source.id);
    if (source.isHourly) {
      final hours = sourceLogs.fold<double>(0, (sum, log) => sum + log.hours);
      final amount = sourceLogs.fold<double>(0, (sum, log) => sum + log.amount);
      if (hours > 0 || amount > 0) {
        snapshots.add(
          IncomeSourceMonthSnapshot(
            sourceId: source.id,
            name: source.name,
            hours: hours,
            amount: amount,
          ),
        );
        grossBase += amount;
      }
    } else if (source.isFixedMonthly && source.fixedMonthlyAmount > 0) {
      snapshots.add(
        IncomeSourceMonthSnapshot(
          sourceId: source.id,
          name: source.name,
          hours: 0,
          amount: source.fixedMonthlyAmount,
        ),
      );
      grossBase += source.fixedMonthlyAmount;
    }
  }

  final fixedAdditions = totalFixedAdditionAmount(fixedItems);
  final fixedExpenses = totalFixedExpenseAmount(fixedItems);
  final gross = grossBase + fixedAdditions;
  final deductionSnapshots = computeGrossDeductionSnapshots(
    gross: gross,
    deductions: deductions,
  );
  final totalDeductions = totalGrossDeductionAmount(deductionSnapshots);
  final totalExpenses = fixedExpenses;
  final net = gross - totalDeductions - totalExpenses;
  final fixedSnapshots = snapshotsFromItems(fixedItems);

  return StudentWorkMonthTotals(
    grossBase: grossBase,
    gross: gross,
    totalDeductions: totalDeductions,
    totalExpenses: totalExpenses,
    net: net,
    sourceSnapshots: snapshots,
    deductionSnapshots: deductionSnapshots,
    fixedMonthlySnapshots: fixedSnapshots,
    totalFixedAdditions: fixedAdditions,
    totalFixedExpenses: fixedExpenses,
  );
}
