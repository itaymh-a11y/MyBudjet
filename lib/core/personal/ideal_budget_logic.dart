import '../models/personal_models.dart';

/// סיכום התפלגות אידיאלית למחזור הנוכחי (הוראות קבע + חלוקה גמישה לפי 6 מחזורים קודמים).
class IdealBudgetSnapshot {
  const IdealBudgetSnapshot({
    required this.budget,
    required this.totalFixedRecurring,
    required this.flexiblePool,
    required this.pastCyclesUsedForAverage,
    required this.categories,
  });

  final double budget;
  /// סכום כל תבניות הוראות הקבע (נוכה מהתקציב לפני חלוקה גמישה).
  final double totalFixedRecurring;
  /// מה שנשאר לחלוקה לפי ממוצע התפלגות גמישה.
  final double flexiblePool;
  /// כמה מחזורים מתוך 6 נכנסו לממוצע (מחזורים ללא הוצאות גמישות מדולגים).
  final int pastCyclesUsedForAverage;
  final List<CategoryBudgetIdeal> categories;
}

class CategoryBudgetIdeal {
  const CategoryBudgetIdeal({
    required this.categoryId,
    required this.categoryName,
    required this.fixedFromRecurring,
    required this.flexiblePortionOfPool,
    required this.idealTotal,
    required this.spentCurrent,
  });

  final String categoryId;
  final String categoryName;
  final double fixedFromRecurring;
  /// חלק מ־0 עד 1 מתוך ה־flexiblePool (אחרי נרמול ממוצעים).
  final double flexiblePortionOfPool;
  final double idealTotal;
  final double spentCurrent;

  bool get isOverIdeal => idealTotal > 0 && spentCurrent > idealTotal;

  /// יחס ניצול מול יעד (מעל 1 = חריגה).
  double get ratioToIdeal => idealTotal > 0 ? spentCurrent / idealTotal : 0;
}

Map<String, double> _sumByCategory(List<PersonalExpense> expenses) {
  final m = <String, double>{};
  for (final e in expenses) {
    m[e.categoryId] = (m[e.categoryId] ?? 0) + e.amount;
  }
  return m;
}

Map<String, double> _fixedByCategory(List<RecurringExpenseTemplate> templates) {
  final m = <String, double>{};
  for (final t in templates) {
    m[t.categoryId] = (m[t.categoryId] ?? 0) + t.amount;
  }
  return m;
}

/// מחשב ממוצע נתחי גמישות לפי 6 מחזורים עבר (רק מחזורים עם flexTotal > 0).
Map<String, double> normalizedFlexibleShares({
  required List<PersonalCategory> categories,
  required Map<String, double> fixedByCategory,
  required List<List<PersonalExpense>> expensesPerPastCycles,
}) {
  final ids = categories.map((c) => c.id).toList();
  final sumShare = {for (final id in ids) id: 0.0};
  var cyclesUsed = 0;

  for (final expenses in expensesPerPastCycles) {
    final spentByCat = _sumByCategory(expenses);
    var flexTotal = 0.0;
    final flexByCat = <String, double>{};
    for (final id in ids) {
      final spent = spentByCat[id] ?? 0;
      final fix = fixedByCategory[id] ?? 0;
      final flex = (spent - fix).clamp(0.0, double.infinity);
      flexByCat[id] = flex;
      flexTotal += flex;
    }
    if (flexTotal <= 0) continue;
    cyclesUsed++;
    for (final id in ids) {
      sumShare[id] = (sumShare[id] ?? 0) + flexByCat[id]! / flexTotal;
    }
  }

  if (cyclesUsed == 0) {
    return {for (final id in ids) id: 0.0};
  }

  final avgRaw = <String, double>{};
  for (final id in ids) {
    avgRaw[id] = (sumShare[id] ?? 0) / cyclesUsed;
  }
  final sumAvg = avgRaw.values.fold<double>(0, (a, b) => a + b);
  if (sumAvg <= 0) {
    return {for (final id in ids) id: 0.0};
  }

  return {for (final id in ids) id: (avgRaw[id] ?? 0) / sumAvg};
}

IdealBudgetSnapshot buildIdealBudgetSnapshot({
  required double budget,
  required List<PersonalCategory> categories,
  required List<RecurringExpenseTemplate> templates,
  required List<List<PersonalExpense>> expensesPerPastCycles,
  required List<PersonalExpense> currentExpenses,
}) {
  final fixedByCategory = _fixedByCategory(templates);
  final fixedTotal =
      fixedByCategory.values.fold<double>(0, (a, b) => a + b);

  final flexiblePool = (budget - fixedTotal).clamp(0.0, double.infinity);

  final normalizedFlex = normalizedFlexibleShares(
    categories: categories,
    fixedByCategory: fixedByCategory,
    expensesPerPastCycles: expensesPerPastCycles,
  );

  var cyclesUsed = 0;
  for (final expenses in expensesPerPastCycles) {
    final spentByCat = _sumByCategory(expenses);
    var flexTotal = 0.0;
    for (final c in categories) {
      final spent = spentByCat[c.id] ?? 0;
      final fix = fixedByCategory[c.id] ?? 0;
      flexTotal += (spent - fix).clamp(0.0, double.infinity);
    }
    if (flexTotal > 0) cyclesUsed++;
  }

  final spentCurrent = _sumByCategory(currentExpenses);

  final rows = <CategoryBudgetIdeal>[];
  for (final c in categories) {
    final fix = fixedByCategory[c.id] ?? 0;
    final portion = normalizedFlex[c.id] ?? 0;
    final flexIdeal = flexiblePool * portion;
    final ideal = fix + flexIdeal;
    final spent = spentCurrent[c.id] ?? 0;
    rows.add(
      CategoryBudgetIdeal(
        categoryId: c.id,
        categoryName: c.name,
        fixedFromRecurring: fix,
        flexiblePortionOfPool: portion,
        idealTotal: ideal,
        spentCurrent: spent,
      ),
    );
  }
  rows.sort((a, b) => b.idealTotal.compareTo(a.idealTotal));

  return IdealBudgetSnapshot(
    budget: budget,
    totalFixedRecurring: fixedTotal,
    flexiblePool: flexiblePool,
    pastCyclesUsedForAverage: cyclesUsed,
    categories: rows,
  );
}
