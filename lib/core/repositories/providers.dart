import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/date_helpers.dart';
import '../models/pension_models.dart';
import '../models/personal_models.dart';
import '../models/user_model.dart';
import 'pension_repository.dart';
import 'personal_repository.dart';
import 'savings_repository.dart';
import 'user_repository.dart';
import '../models/savings_models.dart';
import '../personal/ideal_budget_logic.dart';

class PersonalCycleSummary {
  final double totalSpent;
  final double budget;

  const PersonalCycleSummary({
    required this.totalSpent,
    required this.budget,
  });

  double get ratio => budget <= 0 ? 0 : (totalSpent / budget).clamp(0, 2);
}

/// Firebase base providers

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Repositories

final personalRepositoryProvider = Provider<PersonalRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return PersonalRepository(firestore);
});

final pensionRepositoryProvider = Provider<PensionRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return PensionRepository(firestore);
});

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return SavingsRepository(firestore);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return UserRepository(firestore);
});

/// Auth state

final authStateChangesProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

final currentAuthUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.maybeWhen(
    data: (user) => user,
    orElse: () => ref.watch(firebaseAuthProvider).currentUser,
  );
});

final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final auth = ref.watch(currentAuthUserProvider);
  if (auth == null) return null;
  return ref.watch(userRepositoryProvider).getUser(auth.uid);
});

/// Derived data: personal cycle, expenses and budget

final currentPersonalCycleProvider = Provider<PersonalCycleRange>((ref) {
  final profileAsync = ref.watch(currentUserProfileProvider);
  final startDay = profileAsync.maybeWhen(
    data: (profile) => profile?.personalCycleStartDay ?? 10,
    orElse: () => 10,
  );
  return currentPersonalCycle(DateTime.now(), startDay: startDay);
});

final personalExpensesForCurrentCycleProvider =
    FutureProvider<List<PersonalExpense>>((ref) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return [];

  final repo = ref.watch(personalRepositoryProvider);
  final cycle = ref.watch(currentPersonalCycleProvider);
  return repo.getExpensesForRange(
    userId: user.uid,
    start: cycle.start,
    end: cycle.end,
  );
});

final currentPersonalCycleDocProvider =
    FutureProvider<PersonalCycle?>((ref) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return null;

  final repo = ref.watch(personalRepositoryProvider);
  final cycleRange = ref.watch(currentPersonalCycleProvider);
  return repo.getOrCreateCycle(
    userId: user.uid,
    cycleId: cycleRange.id,
    start: cycleRange.start,
    end: cycleRange.end,
  );
});

/// Derived data: pension current month and recent months

final personalCategoriesProvider =
    FutureProvider<List<PersonalCategory>>((ref) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return [];

  final repo = ref.watch(personalRepositoryProvider);
  await repo.ensurePredefinedCategories(user.uid);
  return repo.getCategories(user.uid);
});

final recurringTemplatesProvider =
    FutureProvider<List<RecurringExpenseTemplate>>((ref) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return [];

  final repo = ref.watch(personalRepositoryProvider);
  return repo.getRecurringTemplates(user.uid);
});

/// מזהה המחזור שעבורו כבר הרצנו הוראות קבע (למניעת כפילות).
class LastRecurringCycleIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final lastRecurringAppliedCycleIdProvider =
    NotifierProvider<LastRecurringCycleIdNotifier, String?>(
        LastRecurringCycleIdNotifier.new);

final personalCycleSummaryProvider =
    FutureProvider<PersonalCycleSummary>((ref) async {
  final expensesFuture =
      ref.watch(personalExpensesForCurrentCycleProvider.future);
  final cycleFuture = ref.watch(currentPersonalCycleDocProvider.future);

  final expenses = await expensesFuture;
  final cycle = await cycleFuture;

  final total = expenses.fold<double>(0, (acc, e) => acc + e.amount);
  final budget = cycle?.budget ?? 0;

  return PersonalCycleSummary(totalSpent: total, budget: budget);
});

/// התפלגות אידיאלית: הוראות קבע (קבוע) + חלוקת שאר התקציב לפי ממוצע 6 מחזורים קודמים.
final personalIdealBudgetProvider =
    FutureProvider<IdealBudgetSnapshot?>((ref) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return null;

  final repo = ref.watch(personalRepositoryProvider);
  final templates = await ref.watch(recurringTemplatesProvider.future);
  final categories = await ref.watch(personalCategoriesProvider.future);
  final cycleDoc = await ref.watch(currentPersonalCycleDocProvider.future);
  final currentExpenses =
      await ref.watch(personalExpensesForCurrentCycleProvider.future);
  final budget = cycleDoc?.budget ?? 0;

  final profileAsync = ref.watch(currentUserProfileProvider);
  final personalStartDay = profileAsync.maybeWhen(
    data: (profile) => profile?.personalCycleStartDay ?? 10,
    orElse: () => 10,
  );
  final ranges = recentPersonalCycleRanges(count: 8, startDay: personalStartDay);
  final pastSix =
      ranges.length > 1 ? ranges.skip(1).take(6).toList() : <PersonalCycleRange>[];

  final expensesPerPastCycles = <List<PersonalExpense>>[];
  for (final r in pastSix) {
    final ex = await repo.getExpensesForRange(
      userId: user.uid,
      start: r.start,
      end: r.end,
    );
    expensesPerPastCycles.add(ex);
  }

  final input = IdealBudgetAiInput(
    budget: budget,
    categories: categories,
    templates: templates,
    expensesPerPastCycles: expensesPerPastCycles,
    currentExpenses: currentExpenses,
  );
  return buildIdealBudgetSnapshot(
    budget: input.budget,
    categories: input.categories,
    templates: input.templates,
    expensesPerPastCycles: input.expensesPerPastCycles,
    currentExpenses: input.currentExpenses,
  );
});

/// הוצאות לפי מזהה מחזור (למשל `2026-03-10`) – לצפייה בהיסטוריה.
final personalExpensesForCycleIdProvider =
    FutureProvider.family<List<PersonalExpense>, String>((ref, cycleId) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return [];

  final range = personalCycleRangeFromId(cycleId);
  if (range == null) return [];

  final repo = ref.watch(personalRepositoryProvider);
  return repo.getExpensesForRange(
    userId: user.uid,
    start: range.start,
    end: range.end,
  );
});

/// מסמך מחזור לפי מזהה – ללא יצירה אוטומטית (רק קריאה).
final personalCycleDocByIdProvider =
    FutureProvider.family<PersonalCycle?, String>((ref, cycleId) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return null;

  final repo = ref.watch(personalRepositoryProvider);
  return repo.getCycle(user.uid, cycleId);
});

final personalCycleSummaryForCycleIdProvider =
    FutureProvider.family<PersonalCycleSummary, String>((ref, cycleId) async {
  final expenses =
      await ref.watch(personalExpensesForCycleIdProvider(cycleId).future);
  final cycle = await ref.watch(personalCycleDocByIdProvider(cycleId).future);

  final total = expenses.fold<double>(0, (acc, e) => acc + e.amount);
  final budget = cycle?.budget ?? 0;

  return PersonalCycleSummary(totalSpent: total, budget: budget);
});

final currentPensionMonthKeyProvider = Provider<PensionMonthKey>((ref) {
  final profileAsync = ref.watch(currentUserProfileProvider);
  final startDay = profileAsync.maybeWhen(
    data: (profile) => profile?.businessCycleStartDay ?? 1,
    orElse: () => 1,
  );
  return currentPensionMonth(DateTime.now(), startDay: startDay);
});

final currentPensionMonthProvider = FutureProvider<PensionMonth?>((ref) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return null;

  final repo = ref.watch(pensionRepositoryProvider);
  final key = ref.watch(currentPensionMonthKeyProvider);
  return repo.getMonth(
    userId: user.uid,
    year: key.year,
    month: key.month,
  );
});

/// נתוני חודש פנסיון לפי year+month נבחר (לעריכה/הצגה של חודשי עבר).
final pensionMonthForProvider =
    FutureProvider.family<PensionMonth?, PensionMonthKey>((ref, key) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return null;
  final repo = ref.watch(pensionRepositoryProvider);
  return repo.getMonth(
    userId: user.uid,
    year: key.year,
    month: key.month,
  );
});

final workHoursForMonthProvider =
    FutureProvider.family<List<WorkHoursEntry>, PensionMonthKey>((ref, key) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return [];
  final profileAsync = ref.watch(currentUserProfileProvider);
  final startDay = profileAsync.maybeWhen(
    data: (profile) => profile?.businessCycleStartDay ?? 1,
    orElse: () => 1,
  );
  final range = businessCycleRangeFromKey(key, startDay: startDay);
  final repo = ref.watch(pensionRepositoryProvider);
  return repo.getWorkHoursForRange(
    userId: user.uid,
    start: range.start,
    end: range.end,
  );
});

final businessIncomeEntriesForMonthProvider =
    FutureProvider.family<List<BusinessIncomeEntry>, PensionMonthKey>(
        (ref, key) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return [];
  final profileAsync = ref.watch(currentUserProfileProvider);
  final startDay = profileAsync.maybeWhen(
    data: (profile) => profile?.businessCycleStartDay ?? 1,
    orElse: () => 1,
  );
  final range = businessCycleRangeFromKey(key, startDay: startDay);
  final repo = ref.watch(pensionRepositoryProvider);
  return repo.getBusinessIncomeForRange(
    userId: user.uid,
    start: range.start,
    end: range.end,
  );
});

final businessExpenseEntriesForMonthProvider =
    FutureProvider.family<List<BusinessExpenseEntry>, PensionMonthKey>(
        (ref, key) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return [];
  final profileAsync = ref.watch(currentUserProfileProvider);
  final startDay = profileAsync.maybeWhen(
    data: (profile) => profile?.businessCycleStartDay ?? 1,
    orElse: () => 1,
  );
  final range = businessCycleRangeFromKey(key, startDay: startDay);
  final repo = ref.watch(pensionRepositoryProvider);
  return repo.getBusinessExpensesForRange(
    userId: user.uid,
    start: range.start,
    end: range.end,
  );
});

final personalExpensesForMonthProvider =
    FutureProvider.family<List<PersonalExpense>, PensionMonthKey>(
        (ref, key) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return [];
  final repo = ref.watch(personalRepositoryProvider);
  final profileAsync = ref.watch(currentUserProfileProvider);
  final startDay = profileAsync.maybeWhen(
    data: (profile) => profile?.businessCycleStartDay ?? 1,
    orElse: () => 1,
  );
  final range = businessCycleRangeFromKey(key, startDay: startDay);
  return repo.getExpensesForRange(
    userId: user.uid,
    start: range.start,
    end: range.end,
  );
});

final recentPensionMonthsProvider =
    FutureProvider.family<List<PensionMonth>, int>((ref, limit) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return [];

  final repo = ref.watch(pensionRepositoryProvider);
  return repo.getRecentMonths(user.uid, limit: limit);
});

/// אחוז חיסכון גלובלי (שינוי לא פוגע ב-snapshot של חודשים קודמים).
final savingsSettingsProvider = FutureProvider<SavingsSettings?>((ref) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return null;
  return ref.watch(savingsRepositoryProvider).getSettings(user.uid);
});

/// רשומת חיסכון לחודש קלנדרי (אחרי סנכרון מפנסיון).
final savingsMonthEntryProvider =
    FutureProvider.family<SavingsMonth?, PensionMonthKey>((ref, key) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return null;
  return ref.watch(savingsRepositoryProvider).getMonth(
        user.uid,
        year: key.year,
        month: key.month,
      );
});

final recentSavingsMonthsProvider =
    FutureProvider.family<List<SavingsMonth>, int>((ref, limit) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return [];
  return ref.watch(savingsRepositoryProvider).getRecentMonths(
        user.uid,
        limit: limit,
      );
});

