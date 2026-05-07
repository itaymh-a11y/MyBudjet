import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PersonalCategory {
  final String id;
  final String userId;
  final String name;
  final String iconName;
  final int? colorValue;
  final bool isDefault;

  const PersonalCategory({
    required this.id,
    required this.userId,
    required this.name,
    this.iconName = 'category',
    this.colorValue,
    this.isDefault = false,
  });

  factory PersonalCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PersonalCategory(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      iconName: data['iconName'] as String? ?? 'category',
      colorValue: data['colorValue'] as int?,
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'iconName': iconName,
      if (colorValue != null) 'colorValue': colorValue,
      'isDefault': isDefault,
    };
  }

  static IconData iconDataFromName(String? iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'bolt':
        return Icons.bolt;
      case 'water_drop':
        return Icons.water_drop;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'restaurant':
        return Icons.restaurant;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'delivery_dining':
        return Icons.delivery_dining;
      case 'medication':
        return Icons.medication;
      case 'medical_services':
        return Icons.medical_services;
      case 'favorite':
        return Icons.favorite;
      case 'local_gas_station':
        return Icons.local_gas_station;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'build':
        return Icons.build;
      case 'local_parking':
        return Icons.local_parking;
      case 'movie':
        return Icons.movie;
      case 'confirmation_number':
        return Icons.confirmation_number;
      case 'beach_access':
        return Icons.beach_access;
      case 'menu_book':
        return Icons.menu_book;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'directions_run':
        return Icons.directions_run;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'school':
        return Icons.school;
      case 'laptop_chromebook':
        return Icons.laptop_chromebook;
      case 'child_care':
        return Icons.child_care;
      case 'checkroom':
        return Icons.checkroom;
      case 'devices':
        return Icons.devices;
      case 'redeem':
        return Icons.redeem;
      case 'face':
        return Icons.face;
      case 'pets':
        return Icons.pets;
      case 'phone':
        return Icons.phone;
      case 'wifi':
        return Icons.wifi;
      case 'tv':
        return Icons.tv;
      case 'flight':
        return Icons.flight;
      case 'hotel':
        return Icons.hotel;
      case 'toys':
        return Icons.toys;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'healing':
        return Icons.healing;
      case 'insurance':
        return Icons.health_and_safety;
      case 'work':
        return Icons.work;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'celebration':
        return Icons.celebration;
      case 'content_cut':
        return Icons.content_cut;
      case 'spa':
        return Icons.spa;
      case 'attach_money':
        return Icons.attach_money;
      case 'account_balance':
        return Icons.account_balance;
      case 'savings':
        return Icons.savings;
      case 'payments':
        return Icons.payments;
      case 'misc':
      default:
        return Icons.category;
    }
  }
}

class PersonalExpense {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final String categoryId;
  final DateTime date;
  final bool isRecurring;
  final int? recurrenceDay;

  const PersonalExpense({
    required this.id,
    required this.userId,
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
      userId: data['userId'] as String? ?? '',
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
      'userId': userId,
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
  final String userId;
  final String title;
  final double amount;
  final String categoryId;
  final int recurrenceDay;

  const RecurringExpenseTemplate({
    required this.id,
    required this.userId,
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
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      categoryId: data['categoryId'] as String? ?? '',
      recurrenceDay: data['recurrenceDay'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'recurrenceDay': recurrenceDay,
    };
  }
}

class PersonalCycle {
  final String id;
  final String userId;
  final DateTime startDate;
  final DateTime endDate;
  final double budget;
  final bool recurringApplied;

  const PersonalCycle({
    required this.id,
    required this.userId,
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
      userId: data['userId'] as String? ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      budget: (data['budget'] as num?)?.toDouble() ?? 0,
      recurringApplied: data['recurringApplied'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'budget': budget,
      'recurringApplied': recurringApplied,
    };
  }
}

