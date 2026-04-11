import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/providers.dart';
import 'personal_ideal_budget_section.dart';

/// תת־פיצ׳ר: התפלגות אידיאלית לפי קטגוריה (הוראות קבע + 6 מחזורים).
class PersonalIdealDistributionScreen extends ConsumerWidget {
  const PersonalIdealDistributionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(personalCycleSummaryProvider);
    final idealAsync = ref.watch(personalIdealBudgetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('התפלגות אידיאלית'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            summaryAsync.when(
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'מחזור נוכחי – סיכום',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'סך הוצאות: ${summary.totalSpent.toStringAsFixed(0)} ₪',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary.budget > 0
                              ? 'תקרת תקציב: ${summary.budget.toStringAsFixed(0)} ₪'
                              : 'לא הוגדר תקציב למחזור',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: summary.budget > 0
                                ? (summary.totalSpent / summary.budget)
                                    .clamp(0, 2)
                                : null,
                            minHeight: 10,
                            backgroundColor: theme
                                .colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Text('שגיאה: $e'),
            ),
            const SizedBox(height: 16),
            idealAsync.when(
              data: (ideal) {
                if (ideal == null) {
                  return const Text('אין נתונים להצגה.');
                }
                return PersonalIdealDistributionBlock(ideal: ideal);
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text(
                'שגיאה בהתפלגות אידיאלית: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
