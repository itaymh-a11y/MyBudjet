import 'package:cloud_firestore/cloud_firestore.dart';

class PensionMonth {
  final String id;
  final int year;
  final int month;
  final double grossIncome;
  final double totalExpenses;
  final double netProfit;

  const PensionMonth({
    required this.id,
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
      year: data['year'] as int? ?? DateTime.now().year,
      month: data['month'] as int? ?? DateTime.now().month,
      grossIncome: (data['grossIncome'] as num?)?.toDouble() ?? 0,
      totalExpenses: (data['totalExpenses'] as num?)?.toDouble() ?? 0,
      netProfit: (data['netProfit'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'month': month,
      'grossIncome': grossIncome,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
    };
  }
}

