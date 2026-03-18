import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/date_helpers.dart';
import '../models/pension_models.dart';
import '../models/personal_models.dart';
import 'pension_repository.dart';
import 'personal_repository.dart';

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

/// Auth state

final authStateChangesProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

/// Derived data: personal cycle, expenses and budget

final currentPersonalCycleProvider = Provider<PersonalCycleRange>((ref) {
  return currentPersonalCycle(DateTime.now());
});

final personalExpensesForCurrentCycleProvider =
    FutureProvider<List<PersonalExpense>>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final user = auth.currentUser;
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
  final auth = ref.watch(firebaseAuthProvider);
  final user = auth.currentUser;
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
  final auth = ref.watch(firebaseAuthProvider);
  final user = auth.currentUser;
  if (user == null) return [];

  final repo = ref.watch(personalRepositoryProvider);
  return repo.getCategories(user.uid);
});

final recurringTemplatesProvider =
    FutureProvider<List<RecurringExpenseTemplate>>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final user = auth.currentUser;
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

final currentPensionMonthKeyProvider = Provider<PensionMonthKey>((ref) {
  return currentPensionMonth(DateTime.now());
});

final currentPensionMonthProvider = FutureProvider<PensionMonth?>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final user = auth.currentUser;
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
  final auth = ref.watch(firebaseAuthProvider).currentUser;
  if (auth == null) return null;
  final repo = ref.watch(pensionRepositoryProvider);
  return repo.getMonth(
    userId: auth.uid,
    year: key.year,
    month: key.month,
  );
});

final recentPensionMonthsProvider =
    FutureProvider.family<List<PensionMonth>, int>((ref, limit) async {
  final auth = ref.watch(firebaseAuthProvider);
  final user = auth.currentUser;
  if (user == null) return [];

  final repo = ref.watch(pensionRepositoryProvider);
  return repo.getRecentMonths(user.uid, limit: limit);
});

