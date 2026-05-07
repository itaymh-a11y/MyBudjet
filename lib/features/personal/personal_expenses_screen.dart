import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/personal_category_bank.dart';
import '../../core/models/personal_models.dart';
import '../../core/repositories/providers.dart';
import 'personal_categories_screen.dart';
import 'personal_cycle_history_screen.dart';
import 'personal_stats_screen.dart';
import 'recurring_expenses_screen.dart';
import 'personal_ideal_distribution_screen.dart';

class PersonalExpensesScreen extends ConsumerWidget {
  const PersonalExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(personalExpensesForCurrentCycleProvider);
    final categoriesAsync = ref.watch(personalCategoriesProvider);
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
          ref.invalidate(personalIdealBudgetProvider);
        });
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('הוצאות אישיות'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'היסטוריית מחזורים',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PersonalCycleHistoryScreen(),
                ),
              );
            },
          ),
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
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'התפלגות אידיאלית',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PersonalIdealDistributionScreen(),
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

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'סך הוצאות במחזור: ${summary.totalSpent.toStringAsFixed(0)} ₪',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          summary.budget > 0
                              ? 'תקרת תקציב: ${summary.budget.toStringAsFixed(0)} ₪'
                              : 'לא הוגדר תקציב למחזור זה',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: summary.budget > 0
                                ? (summary.totalSpent / summary.budget)
                                    .clamp(0, 2)
                                : null,
                            minHeight: 10,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                final categoriesById = <String, PersonalCategory>{
                  for (final c in categoriesAsync.maybeWhen(
                    data: (value) => value,
                    orElse: () => const <PersonalCategory>[],
                  ))
                    c.id: c,
                };
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
                    final category = categoriesById[expense.categoryId];
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
                          ..invalidate(personalCycleSummaryProvider)
                          ..invalidate(personalIdealBudgetProvider);
                      },
                      categoryName: category?.name,
                      categoryIconName: category?.iconName,
                    );
                  },
                  separatorBuilder: (_, _) => const Divider(),
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
      ..invalidate(personalCycleSummaryProvider)
      ..invalidate(personalIdealBudgetProvider);
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
                userId: auth.uid,
                startDate: cycle.startDate,
                endDate: cycle.endDate,
                budget: value,
              );
              await repo.upsertCycle(auth.uid, updated);
              ref
                ..invalidate(currentPersonalCycleDocProvider)
                ..invalidate(personalCycleSummaryProvider)
                ..invalidate(personalIdealBudgetProvider);
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
    this.categoryIconName,
  });

  final PersonalExpense expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String? categoryName;
  final String? categoryIconName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _categoryAccent(categoryName ?? categoryIconName ?? 'misc');
    return Container(
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: accent.withOpacity(0.18),
          child: Icon(
            PersonalCategory.iconDataFromName(categoryIconName),
            color: accent,
            size: 18,
          ),
        ),
        title: Text(
          expense.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
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
                color: accent,
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
      ),
    );
  }

  Color _categoryAccent(String key) {
    final palette = <Color>[
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFFF97316),
      const Color(0xFF14B8A6),
      const Color(0xFF0EA5E9),
      const Color(0xFF84CC16),
      const Color(0xFF8B5CF6),
    ];
    final index = key.hashCode.abs() % palette.length;
    return palette[index];
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
  String? _pendingCategoryName;
  String _pendingCategoryIconName = 'category';

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
    var categoryId = _selectedCategoryId;
    if (categoryId == null && _pendingCategoryName != null) {
      final newCategoryId = DateTime.now().millisecondsSinceEpoch.toString();
      await repo.upsertCategory(
        user.uid,
        PersonalCategory(
          id: newCategoryId,
          userId: user.uid,
          name: _pendingCategoryName!,
          iconName: _pendingCategoryIconName,
        ),
      );
      categoryId = newCategoryId;
      ref.invalidate(personalCategoriesProvider);
    }
    categoryId ??= categories.isNotEmpty ? categories.first.id : 'other';

    final expense = PersonalExpense(
      id: widget.existing?.id ?? '',
      userId: user.uid,
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

  Future<void> _openCategoryPicker(List<PersonalCategory> categories) async {
    final selected = await showDialog<_CategoryPickerResult>(
      context: context,
      builder: (context) => _CategoryPickerDialog(
        categories: categories,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedCategoryId = selected.categoryId;
      _pendingCategoryName = selected.newCategoryName;
      _pendingCategoryIconName = selected.iconName ?? 'category';
    });
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
                    _selectedCategoryId ??=
                        widget.existingCategoryId ?? categories.first.id;
                    final selectedCategory = categories.where((c) {
                      return c.id == _selectedCategoryId;
                    }).toList();
                    final title = _pendingCategoryName ??
                        (selectedCategory.isNotEmpty
                            ? selectedCategory.first.name
                            : 'בחר קטגוריה');
                    final iconName = _pendingCategoryName != null
                        ? _pendingCategoryIconName
                        : (selectedCategory.isNotEmpty
                            ? selectedCategory.first.iconName
                            : 'category');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(PersonalCategory.iconDataFromName(iconName)),
                      ),
                      title: const Text('קטגוריה'),
                      subtitle: Text(title),
                      trailing: const Icon(Icons.search),
                      onTap: () => _openCategoryPicker(categories),
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

class _CategoryPickerResult {
  final String? categoryId;
  final String? newCategoryName;
  final String? iconName;

  const _CategoryPickerResult({
    this.categoryId,
    this.newCategoryName,
    this.iconName,
  });
}

class _CategoryPickerDialog extends StatefulWidget {
  const _CategoryPickerDialog({required this.categories});

  final List<PersonalCategory> categories;

  @override
  State<_CategoryPickerDialog> createState() => _CategoryPickerDialogState();
}

class _CategoryPickerDialogState extends State<_CategoryPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim();
    final existingByName = {
      for (final c in widget.categories) c.name.trim(): c,
    };

    final filtered = PersonalCategoryBank.categories.where((predefined) {
      if (normalizedQuery.isEmpty) return true;
      return predefined.name.contains(normalizedQuery);
    }).toList();

    return AlertDialog(
      title: const Text('בחירת קטגוריה'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'חפש קטגוריה...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: filtered.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.6,
                ),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final existing = existingByName[item.name];
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (existing != null) {
                        Navigator.of(context).pop(
                          _CategoryPickerResult(
                            categoryId: existing.id,
                            iconName: existing.iconName,
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).pop(
                        _CategoryPickerResult(
                          categoryId: null,
                          newCategoryName: item.name,
                          iconName: item.iconName,
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(PersonalCategory.iconDataFromName(item.iconName)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

