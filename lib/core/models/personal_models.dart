import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalCategory {
  final String id;
  final String name;
  final int? colorValue;
  final bool isDefault;

  const PersonalCategory({
    required this.id,
    required this.name,
    this.colorValue,
    this.isDefault = false,
  });

  factory PersonalCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PersonalCategory(
      id: doc.id,
      name: data['name'] as String? ?? '',
      colorValue: data['colorValue'] as int?,
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (colorValue != null) 'colorValue': colorValue,
      'isDefault': isDefault,
    };
  }
}

class PersonalExpense {
  final String id;
  final String title;
  final double amount;
  final String categoryId;
  final DateTime date;
  final bool isRecurring;
  final int? recurrenceDay;

  const PersonalExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.isRecurring = false,
    this.recurrenceDay,
  });

  factory PersonalExpense.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PersonalExpense(
      id: doc.id,
      title: data['title'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      categoryId: data['categoryId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRecurring: data['isRecurring'] as bool? ?? false,
      recurrenceDay: data['recurrenceDay'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'date': Timestamp.fromDate(date),
      'isRecurring': isRecurring,
      if (recurrenceDay != null) 'recurrenceDay': recurrenceDay,
    };
  }
}

/// תבנית הוצאה קבועה – מתווספת אוטומטית בתחילת כל מחזור.
class RecurringExpenseTemplate {
  final String id;
  final String title;
  final double amount;
  final String categoryId;
  final int recurrenceDay;

  const RecurringExpenseTemplate({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    this.recurrenceDay = 10,
  });

  factory RecurringExpenseTemplate.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return RecurringExpenseTemplate(
      id: doc.id,
      title: data['title'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      categoryId: data['categoryId'] as String? ?? '',
      recurrenceDay: data['recurrenceDay'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'recurrenceDay': recurrenceDay,
    };
  }
}

class PersonalCycle {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final double budget;
  final bool recurringApplied;

  const PersonalCycle({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.budget,
    this.recurringApplied = false,
  });

  factory PersonalCycle.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PersonalCycle(
      id: doc.id,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      budget: (data['budget'] as num?)?.toDouble() ?? 0,
      recurringApplied: data['recurringApplied'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'budget': budget,
      'recurringApplied': recurringApplied,
    };
  }
}

