import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/date_helpers.dart';
import '../../core/models/personal_models.dart';
import '../../core/repositories/providers.dart';
import 'personal_cycle_stats_body.dart';

/// רשימת מחזורים אחרונים – בחירה פותחת פירוט + גרף עוגה.
class PersonalCycleHistoryScreen extends ConsumerWidget {
  const PersonalCycleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPersonalCycleProvider);
    final cycles = recentPersonalCycleRanges(count: 48);

    return Scaffold(
      appBar: AppBar(
        title: const Text('היסטוריית מחזורים'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: cycles.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final c = cycles[index];
          final isCurrent = c.id == current.id;
          return ListTile(
            title: Text(
              '${c.start.day}.${c.start.month}.${c.start.year} – '
              '${c.end.day}.${c.end.month}.${c.end.year}',
            ),
            subtitle: Text(
              isCurrent ? 'מחזור נוכחי' : 'הקש לפירוט והתפלגות',
              style: TextStyle(
                color: isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PersonalCycleDetailScreen(cycleId: c.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PersonalCycleDetailScreen extends ConsumerWidget {
  const PersonalCycleDetailScreen({super.key, required this.cycleId});

  final String cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = personalCycleRangeFromId(cycleId);
    if (range == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('מחזור')),
        body: const Center(child: Text('מזהה מחזור לא תקין')),
      );
    }

    final expensesAsync = ref.watch(personalExpensesForCycleIdProvider(cycleId));
    final categoriesAsync = ref.watch(personalCategoriesProvider);
    final summaryAsync = ref.watch(personalCycleSummaryForCycleIdProvider(cycleId));
    final current = ref.watch(currentPersonalCycleProvider);
    final isCurrent = cycleId == current.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${range.start.day}.${range.start.month}.${range.start.year} – '
          '${range.end.day}.${range.end.month}.${range.end.year}',
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: summaryAsync.when(
              data: (summary) {
                final theme = Theme.of(context);
                final ratio = summary.ratio;
                Color barColor;
                if (summary.budget <= 0) {
                  barColor = theme.colorScheme.outlineVariant;
                } else if (ratio < 0.6) {
                  barColor = Colors.green;
                } else if (ratio < 0.85) {
                  barColor = Colors.orange;
                } else {
                  barColor = Colors.red;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isCurrent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'מחזור נוכחי – ניתן לערוך במסך הראשי',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    Text(
                      'סך הוצאות במחזור: ${summary.totalSpent.toStringAsFixed(0)} ₪',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary.budget > 0
                          ? 'תקרת תקציב (אם הוגדרה): ${summary.budget.toStringAsFixed(0)} ₪'
                          : 'לא הוגדר תקציב למחזור זה בהיסטוריה',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: summary.budget > 0
                            ? (summary.totalSpent / summary.budget).clamp(0, 2)
                            : null,
                        minHeight: 10,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('שגיאה: $e'),
            ),
          ),
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                return categoriesAsync.when(
                  data: (categories) {
                    return DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'התפלגות'),
                              Tab(text: 'פירוט הוצאות'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: PersonalCycleStatsBody(
                                    expenses: expenses,
                                    categories: categories,
                                  ),
                                ),
                                _ExpenseListReadOnly(
                                  expenses: expenses,
                                  categories: categories,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('שגיאה בקטגוריות: $e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('שגיאה בהוצאות: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseListReadOnly extends StatelessWidget {
  const _ExpenseListReadOnly({
    required this.expenses,
    required this.categories,
  });

  final List<PersonalExpense> expenses;
  final List<PersonalCategory> categories;

  PersonalCategory _category(String categoryId) {
    return categories
        .firstWhere(
          (c) => c.id == categoryId,
          orElse: () => PersonalCategory(
            id: categoryId,
            userId: '',
            name: '—',
            iconName: 'category',
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const Center(
        child: Text('אין הוצאות רשומות במחזור זה.'),
      );
    }
    final sorted = List<PersonalExpense>.from(expenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final e = sorted[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 16,
            child: Icon(
              PersonalCategory.iconDataFromName(_category(e.categoryId).iconName),
              size: 18,
            ),
          ),
          title: Text(e.title),
          subtitle: Text(
            '${e.date.day}.${e.date.month}.${e.date.year} • ${_category(e.categoryId).name}',
          ),
          trailing: Text(
            '${e.amount.toStringAsFixed(0)} ₪',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        );
      },
    );
  }
}
