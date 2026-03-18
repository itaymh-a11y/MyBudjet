import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/personal_models.dart';
import '../../core/repositories/providers.dart';

/// מסך הוראות קבע – רשימת תבניות הוצאות שמוספות אוטומטית בכל מחזור.
class RecurringExpensesScreen extends ConsumerWidget {
  const RecurringExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(recurringTemplatesProvider);
    final categoriesAsync = ref.watch(personalCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('הוראות קבע'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'הוספת הוראה',
            onPressed: () => _openEditDialog(context, ref, null, categoriesAsync),
          ),
        ],
      ),
      body: templatesAsync.when(
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'אין עדיין הוראות קבע.\nהוצאות שתוסיף כאן יתווספו אוטומטית בתחילת כל מחזור (כל 10 בחודש).',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _openEditDialog(
                          context, ref, null, categoriesAsync),
                      icon: const Icon(Icons.add),
                      label: const Text('הוסף הוראה'),
                    ),
                  ],
                ),
              ),
            );
          }
          final total = templates.fold<double>(0, (s, t) => s + t.amount);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'סה״כ הוראות קבע: ${total.toStringAsFixed(0)} ₪',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'סכום זה יתווסף אוטומטית בתחילת כל מחזור.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _runRecurringForCurrentCycle(
                              context, ref),
                          icon: const Icon(Icons.play_arrow, size: 20),
                          label: const Text(
                            'הפעל הוראות קבע למחזור הנוכחי',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final t = templates[index];
                    return categoriesAsync.when(
                      data: (categories) {
                        final name = categories
                                .where((c) => c.id == t.categoryId)
                                .map((c) => c.name)
                                .firstOrNull ??
                            t.categoryId;
                        return ListTile(
                          title: Text(t.title),
                          subtitle: Text('$name • ${t.amount.toStringAsFixed(0)} ₪'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openEditDialog(
                                    context, ref, t, categoriesAsync),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteTemplate(context, ref, t),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => ListTile(
                        title: Text(t.title),
                        subtitle: Text('${t.amount.toStringAsFixed(0)} ₪'),
                      ),
                      error: (_, __) => ListTile(
                        title: Text(t.title),
                        subtitle: Text('${t.amount.toStringAsFixed(0)} ₪'),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('שגיאה: $e')),
      ),
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    RecurringExpenseTemplate? existing,
    AsyncValue<List<PersonalCategory>> categoriesAsync,
  ) async {
    final categories = categoriesAsync.value ?? [];
    if (categories.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('נא להגדיר קטגוריות לפני הוספת הוראה.')),
        );
      }
      return;
    }

    final titleController = TextEditingController(text: existing?.title ?? '');
    final amountController =
        TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    String? categoryId = existing?.categoryId ?? categories.first.id;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'הוראה חדשה' : 'עריכת הוראה'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'תיאור',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'סכום (₪)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: categoryId,
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => categoryId = v),
                    decoration: const InputDecoration(
                      labelText: 'קטגוריה',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ביטול'),
              ),
              FilledButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  final amount = double.tryParse(
                      amountController.text.trim().replaceAll(',', '.'));
                  if (title.isEmpty || amount == null || amount <= 0) return;
                  Navigator.of(context).pop(true);
                },
                child: const Text('שמור'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true || !context.mounted) return;

    final title = titleController.text.trim();
    final amount = double.tryParse(
        amountController.text.trim().replaceAll(',', '.'));
    if (title.isEmpty || amount == null || amount <= 0) return;

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final repo = ref.read(personalRepositoryProvider);
    final template = RecurringExpenseTemplate(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      categoryId: categoryId ?? categories.first.id,
      recurrenceDay: existing?.recurrenceDay ?? 10,
    );

    if (existing == null) {
      await repo.addRecurringTemplate(user.uid, template);
    } else {
      await repo.updateRecurringTemplate(user.uid, template);
    }
    ref.invalidate(recurringTemplatesProvider);
    ref.read(lastRecurringAppliedCycleIdProvider.notifier).set(null);
  }

  Future<void> _runRecurringForCurrentCycle(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final cycleDoc = await ref.read(currentPersonalCycleDocProvider.future);
    if (cycleDoc == null) return;
    final repo = ref.read(personalRepositoryProvider);
    ref.read(lastRecurringAppliedCycleIdProvider.notifier).set(null);
    await repo.setCycleRecurringApplied(user.uid, cycleDoc.id, false);
    await repo.applyRecurringExpensesForCycle(
      userId: user.uid,
      cycleId: cycleDoc.id,
      cycleStart: cycleDoc.startDate,
    );
    ref.invalidate(currentPersonalCycleDocProvider);
    ref.invalidate(personalExpensesForCurrentCycleProvider);
    ref.invalidate(personalCycleSummaryProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הוראות הקבע הופעלו. רענן את מסך ההוצאות האישיות.'),
        ),
      );
    }
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    RecurringExpenseTemplate t,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת הוראה'),
        content: Text(
            'למחוק את "${t.title}"? ההוצאה לא תתווסף במחזורים הבאים.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('מחק'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    await ref.read(personalRepositoryProvider).deleteRecurringTemplate(
          user.uid,
          t.id,
        );
    ref.invalidate(recurringTemplatesProvider);
    ref.read(lastRecurringAppliedCycleIdProvider.notifier).set(null);
  }
}
