import 'package:cloud_firestore/cloud_firestore.dart';

/// הגדרות אחוז חיסכון גלובלי (שינוי לא משפיע רטרואקטיבית על snapshot בכל חודש).
class SavingsSettings {
  final double savingsPercent;
  final DateTime updatedAt;

  const SavingsSettings({
    required this.savingsPercent,
    required this.updatedAt,
  });

  factory SavingsSettings.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SavingsSettings(
      savingsPercent: (data['savingsPercent'] as num?)?.toDouble() ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'savingsPercent': savingsPercent,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// רשומת חיסכון לחודש קלנדרי – היעד מחושב מנטו הפנסיון (אחרי שמירה בפנסיון).
class SavingsMonth {
  final String id;
  final int year;
  final int month;
  final double targetAmount;
  /// האחוז שנשמר בזמן עדכון היעד (לא משתנה כשמשנים את ההגדרה הגלובלית).
  final double percentSnapshot;
  final double pensionNetSnapshot;
  final bool deposited;
  final DateTime? depositedAt;
  final DateTime updatedAt;

  const SavingsMonth({
    required this.id,
    required this.year,
    required this.month,
    required this.targetAmount,
    required this.percentSnapshot,
    required this.pensionNetSnapshot,
    required this.deposited,
    this.depositedAt,
    required this.updatedAt,
  });

  factory SavingsMonth.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SavingsMonth(
      id: doc.id,
      year: data['year'] as int? ?? DateTime.now().year,
      month: data['month'] as int? ?? DateTime.now().month,
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0,
      percentSnapshot: (data['percentSnapshot'] as num?)?.toDouble() ?? 0,
      pensionNetSnapshot: (data['pensionNetSnapshot'] as num?)?.toDouble() ?? 0,
      deposited: data['deposited'] as bool? ?? false,
      depositedAt: (data['depositedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'month': month,
      'targetAmount': targetAmount,
      'percentSnapshot': percentSnapshot,
      'pensionNetSnapshot': pensionNetSnapshot,
      'deposited': deposited,
      if (depositedAt != null) 'depositedAt': Timestamp.fromDate(depositedAt!),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
