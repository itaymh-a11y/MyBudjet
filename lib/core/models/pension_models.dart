import 'package:cloud_firestore/cloud_firestore.dart';

class PensionMonth {
  final String id;
  final String userId;
  final int year;
  final int month;
  final double grossIncome;
  final double totalExpenses;
  final double netProfit;

  const PensionMonth({
    required this.id,
    required this.userId,
    required this.year,
    required this.month,
    required this.grossIncome,
    required this.totalExpenses,
    required this.netProfit,
  });

  factory PensionMonth.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PensionMonth(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      year: data['year'] as int? ?? DateTime.now().year,
      month: data['month'] as int? ?? DateTime.now().month,
      grossIncome: (data['grossIncome'] as num?)?.toDouble() ?? 0,
      totalExpenses: (data['totalExpenses'] as num?)?.toDouble() ?? 0,
      netProfit: (data['netProfit'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'year': year,
      'month': month,
      'grossIncome': grossIncome,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
    };
  }
}

class WorkHoursEntry {
  final String id;
  final String userId;
  final DateTime date;
  final double hours;
  final double hourlyRateSnapshot;
  final DateTime createdAt;

  const WorkHoursEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.hours,
    required this.hourlyRateSnapshot,
    required this.createdAt,
  });

  factory WorkHoursEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return WorkHoursEntry(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hours: (data['hours'] as num?)?.toDouble() ?? 0.0,
      hourlyRateSnapshot:
          (data['hourlyRateSnapshot'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'hours': hours,
      'hourlyRateSnapshot': hourlyRateSnapshot,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class BusinessIncomeEntry {
  final String id;
  final String userId;
  final DateTime date;
  final double amount;
  final DateTime createdAt;

  const BusinessIncomeEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.amount,
    required this.createdAt,
  });

  factory BusinessIncomeEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BusinessIncomeEntry(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class BusinessExpenseEntry {
  final String id;
  final String userId;
  final DateTime date;
  final double amount;
  final DateTime createdAt;

  const BusinessExpenseEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.amount,
    required this.createdAt,
  });

  factory BusinessExpenseEntry.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BusinessExpenseEntry(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

