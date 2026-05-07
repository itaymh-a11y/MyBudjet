import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/personal_category_bank.dart';
import '../models/date_helpers.dart';
import '../models/personal_models.dart';
import 'firestore_paths.dart';

class PersonalRepository {
  PersonalRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _categoriesRef(String userId) =>
      _firestore.collection(FirestorePaths.personalCategories(userId));

  CollectionReference<Map<String, dynamic>> _expensesRef(String userId) =>
      _firestore.collection(FirestorePaths.personalExpenses(userId));

  CollectionReference<Map<String, dynamic>> _cyclesRef(String userId) =>
      _firestore.collection(FirestorePaths.personalCycles(userId));

  CollectionReference<Map<String, dynamic>> _recurringRef(String userId) =>
      _firestore.collection(FirestorePaths.recurringExpenseTemplates(userId));

  Future<List<PersonalCategory>> getCategories(String userId) async {
    final snapshot = await _categoriesRef(userId).get();
    return snapshot.docs.map(PersonalCategory.fromDoc).toList();
  }

  Future<void> ensurePredefinedCategories(String userId) async {
    final existing = await getCategories(userId);
    final existingNames = existing.map((c) => c.name.trim()).toSet();
    final batch = _firestore.batch();
    var hasWrites = false;

    for (var i = 0; i < PersonalCategoryBank.categories.length; i++) {
      final predefined = PersonalCategoryBank.categories[i];
      if (existingNames.contains(predefined.name.trim())) continue;
      final id = 'predef_${(i + 1).toString().padLeft(3, '0')}';
      final docRef = _categoriesRef(userId).doc(id);
      final category = PersonalCategory(
        id: id,
        userId: userId,
        name: predefined.name,
        iconName: predefined.iconName,
        isDefault: true,
      );
      batch.set(docRef, {
        ...category.toMap(),
        'userId': userId,
      });
      hasWrites = true;
    }

    if (hasWrites) {
      await batch.commit();
    }
  }

  Future<void> upsertCategory(String userId, PersonalCategory category) async {
    await _categoriesRef(userId).doc(category.id).set({
      ...category.toMap(),
      'userId': userId,
    });
  }

  Future<void> deleteCategory(String userId, String categoryId) async {
    await _categoriesRef(userId).doc(categoryId).delete();
  }

  Future<List<PersonalExpense>> getExpensesForRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _expensesRef(userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date')
        .get();
    return snapshot.docs.map(PersonalExpense.fromDoc).toList();
  }

  Future<void> addExpense(String userId, PersonalExpense expense) async {
    await _expensesRef(userId).add({
      ...expense.toMap(),
      'userId': userId,
    });
  }

  Future<void> updateExpense(String userId, PersonalExpense expense) async {
    await _expensesRef(userId).doc(expense.id).update({
      ...expense.toMap(),
      'userId': userId,
    });
  }

  Future<void> deleteExpense(String userId, String expenseId) async {
    await _expensesRef(userId).doc(expenseId).delete();
  }

  Future<PersonalCycle?> getCycle(String userId, String cycleId) async {
    final doc = await _cyclesRef(userId).doc(cycleId).get();
    if (!doc.exists) return null;
    return PersonalCycle.fromDoc(doc);
  }

  Future<void> upsertCycle(String userId, PersonalCycle cycle) async {
    await _cyclesRef(userId).doc(cycle.id).set({
      ...cycle.toMap(),
      'userId': userId,
    });
  }

  Future<PersonalCycle> getOrCreateCycle({
    required String userId,
    required String cycleId,
    required DateTime start,
    required DateTime end,
  }) async {
    final existing = await getCycle(userId, cycleId);
    if (existing != null) return existing;

    double budget = 0;
    final prevId = previousPersonalCycleId(cycleId);
    final prevCycle = await getCycle(userId, prevId);
    if (prevCycle != null) budget = prevCycle.budget;

    final newCycle = PersonalCycle(
      id: cycleId,
      userId: userId,
      startDate: start,
      endDate: end,
      budget: budget,
      recurringApplied: false,
    );
    await upsertCycle(userId, newCycle);
    return newCycle;
  }

  Future<void> setCycleRecurringApplied(
    String userId,
    String cycleId,
    bool applied,
  ) async {
    final cycle = await getCycle(userId, cycleId);
    if (cycle == null) return;
    await _cyclesRef(userId).doc(cycleId).update({
      'recurringApplied': applied,
    });
  }

  Future<List<RecurringExpenseTemplate>> getRecurringTemplates(
    String userId,
  ) async {
    final snapshot = await _recurringRef(userId).get();
    return snapshot.docs
        .map((d) => RecurringExpenseTemplate.fromDoc(d))
        .toList();
  }

  Future<void> addRecurringTemplate(
    String userId,
    RecurringExpenseTemplate template,
  ) async {
    await _recurringRef(userId).doc(template.id).set({
      ...template.toMap(),
      'userId': userId,
    });
  }

  Future<void> updateRecurringTemplate(
    String userId,
    RecurringExpenseTemplate template,
  ) async {
    await _recurringRef(userId).doc(template.id).set({
      ...template.toMap(),
      'userId': userId,
    });
  }

  Future<void> deleteRecurringTemplate(
    String userId,
    String templateId,
  ) async {
    await _recurringRef(userId).doc(templateId).delete();
  }

  /// יוצר הוצאות במחזור הנוכחי מכל תבניות הוראות הקבע. קוראים פעם אחת למחזור.
  Future<void> applyRecurringExpensesForCycle({
    required String userId,
    required String cycleId,
    required DateTime cycleStart,
  }) async {
    final cycle = await getCycle(userId, cycleId);
    if (cycle == null || cycle.recurringApplied) return;

    final templates = await getRecurringTemplates(userId);
    if (templates.isEmpty) {
      return;
    }

    for (final t in templates) {
      final day = t.recurrenceDay.clamp(1, 28);
      final date = DateTime(cycleStart.year, cycleStart.month, day);
      final expense = PersonalExpense(
        id: '',
        userId: userId,
        title: t.title,
        amount: t.amount,
        categoryId: t.categoryId,
        date: date,
        isRecurring: false,
        recurrenceDay: null,
      );
      await addExpense(userId, expense);
    }

    await setCycleRecurringApplied(userId, cycleId, true);
  }
}

