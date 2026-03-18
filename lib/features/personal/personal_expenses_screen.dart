import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/personal_models.dart';
import '../../core/repositories/providers.dart';
import 'personal_categories_screen.dart';
import 'personal_stats_screen.dart';
import 'recurring_expenses_screen.dart';

class PersonalExpensesScreen extends ConsumerWidget {
  const PersonalExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(personalExpensesForCurrentCycleProvider);
    final cycle = ref.watch(currentPersonalCycleProvider);
    final summaryAsync = ref.watch(personalCycleSummaryProvider);
    ref.watch(currentPersonalCycleDocProvider);

    ref.listen(currentPersonalCycleDocProvider, (prev, next) {
      next.whenData((cycleDoc) {
        if (cycleDoc == null || cycleDoc.recurringApplied) return;
        final lastId = ref.read(lastRecurringAppliedCycleIdProvider);
        if (lastId == cycleDoc.id) return;
        ref.read(lastRecurringAppliedCycleIdProvider.notifier).set(cycleDoc.id);
        Future.microtask(() async {
          final user = ref.read(firebaseAuthProvider).currentUser;
          if (user == null) return;
          final repo = ref.read(personalRepositoryProvider);
          await repo.applyRecurringExpensesForCycle(
            userId: user.uid,
            cycleId: cycleDoc.id,
            cycleStart: cycleDoc.startDate,
          );
          ref.invalidate(currentPersonalCycleDocProvider);
          ref.invalidate(personalExpensesForCurrentCycleProvider);
          ref.invalidate(personalCycleSummaryProvider);
        });
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('הוצאות אישיות'),
        actions: [
          IconButton(
            icon: const Icon(Icons.repeat),
            tooltip: 'הוראות קבע',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecurringExpensesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'סטטיסטיקה',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PersonalStatsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'הגדרת תקציב למחזור',
            onPressed: () => _openBudgetDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'ניהול קטגוריות',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PersonalCategoriesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
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
                    Text(
                      'סך הוצאות במחזור: ${summary.totalSpent.toStringAsFixed(0)} ₪',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary.budget > 0
                          ? 'תקרת תקציב: ${summary.budget.toStringAsFixed(0)} ₪'
                          : 'לא הוגדר תקציב למחזור זה',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: summary.budget > 0
                            ? (summary.totalSpent / summary.budget)
                                .clamp(0, 2)
                            : null,
                        minHeight: 10,
                        backgroundColor:
                            theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('שגיאה בסיכום הוצאות: $e'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Center(
                    child: Text(
                      'אין הוצאות במחזור הנוכחי.\nלחץ על + כדי להוסיף.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return _ExpenseTile(
                      expense: expense,
                      onTap: () => _openAddExpenseSheet(
                        context,
                        ref,
                        existing: expense,
                      ),
                      onDelete: () async {
                        final auth =
                            ref.read(firebaseAuthProvider).currentUser;
                        if (auth == null) return;
                        final repo = ref.read(personalRepositoryProvider);
                        await repo.deleteExpense(auth.uid, expense.id);
                        ref
                          ..invalidate(
                              personalExpensesForCurrentCycleProvider)
                          ..invalidate(personalCycleSummaryProvider);
                      },
                      categoryName: null,
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: expenses.length,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('שגיאה בטעינת הוצאות: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddExpenseSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('הוצאה חדשה'),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'מחזור נוכחי: '
          '${cycle.start.day}.${cycle.start.month}.${cycle.start.year} - '
          '${cycle.end.day}.${cycle.end.month}.${cycle.end.year}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _openAddExpenseSheet(
    BuildContext context,
    WidgetRef ref, {
    PersonalExpense? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _AddExpenseSheet(
          existing: existing,
          existingCategoryId: existing?.categoryId,
        ),
      ),
    );

    // ריענון רשימת ההוצאות לאחר סגירת הטופס.
    ref
      ..invalidate(personalExpensesForCurrentCycleProvider)
      ..invalidate(personalCycleSummaryProvider);
  }

  Future<void> _openBudgetDialog(BuildContext context, WidgetRef ref) async {
    final cycle = await ref.read(currentPersonalCycleDocProvider.future);
    final controller = TextEditingController(
      text: cycle?.budget.toStringAsFixed(0) ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('הגדרת תקציב למחזור'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'תקציב (₪)',
          ),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              final value = double.tryParse(text.replaceAll(',', '.'));
              if (value == null || value < 0) return;

              final auth = ref.read(firebaseAuthProvider).currentUser;
              if (auth == null || cycle == null) return;

              final repo = ref.read(personalRepositoryProvider);
              final updated = PersonalCycle(
                id: cycle.id,
                startDate: cycle.startDate,
                endDate: cycle.endDate,
                budget: value,
              );
              await repo.upsertCycle(auth.uid, updated);
              ref
                ..invalidate(currentPersonalCycleDocProvider)
                ..invalidate(personalCycleSummaryProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.onTap,
    required this.onDelete,
    this.categoryName,
  });

  final PersonalExpense expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      title: Text(expense.title),
      subtitle: Text(
        '${expense.date.day}.${expense.date.month}.${expense.date.year}'
        '${expense.isRecurring ? ' • הוצאה קבועה' : ''}'
        '${categoryName != null ? ' • $categoryName' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            expense.amount.toStringAsFixed(0),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: theme.colorScheme.error,
            tooltip: 'מחיקת הוצאה',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('מחיקת הוצאה'),
                      content: const Text(
                        'האם אתה בטוח שברצונך למחוק הוצאה זו?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop(false),
                          child: const Text('ביטול'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(true),
                          child: const Text('מחק'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (confirmed) {
                onDelete();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet({this.existing, this.existingCategoryId});

  final PersonalExpense? existing;
  final String? existingCategoryId;

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;
    if (user == null) return;

    final repo = ref.read(personalRepositoryProvider);
    final categories = await ref.read(personalCategoriesProvider.future);
    final categoryId =
        _selectedCategoryId ?? (categories.isNotEmpty ? categories.first.id : 'other');

    final expense = PersonalExpense(
      id: widget.existing?.id ?? '',
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      categoryId: categoryId,
      date: _selectedDate,
      isRecurring: false,
      recurrenceDay: null,
    );

    if (widget.existing == null) {
      await repo.addExpense(user.uid, expense);
    } else {
      await repo.updateExpense(user.uid, expense);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'הוצאה חדשה' : 'עריכת הוצאה',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'תיאור ההוצאה',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'נא להזין תיאור';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'סכום (₪)',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'נא להזין סכום';
                }
                final parsed = double.tryParse(value.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) {
                  return 'נא להזין סכום תקין';
                }
                return null;
              },
              onChanged: (value) {
                // המרה אוטומטית של פסיק לנקודה בעת שמירה.
                if (value.contains(',')) {
                  final newValue = value.replaceAll(',', '.');
                  _amountController
                    ..text = newValue
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: newValue.length),
                    );
                }
              },
            ),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) {
                final categoriesAsync = ref.watch(personalCategoriesProvider);
                return categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Text('אין קטגוריות – נא להגדיר קטגוריות לפני הוספת הוצאות.');
                    }
                    _selectedCategoryId ??= widget.existingCategoryId ??
                        categories.first.id;
                    return DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedCategoryId = v;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'קטגוריה',
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                  loading: () =>
                      const LinearProgressIndicator(minHeight: 2),
                  error: (e, _) => Text('שגיאה בטעינת קטגוריות: $e'),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'תאריך: ${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                  ),
                ),
                TextButton(
                  onPressed: () => _pickDate(context),
                  child: const Text('בחר תאריך'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('שמור הוצאה'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

