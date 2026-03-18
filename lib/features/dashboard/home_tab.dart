import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/providers.dart';

/// מסך בית – תצוגת סיכום: Progress Bar אישי + כרטיס פנסיון + קישורים מהירים.
class HomeTab extends ConsumerWidget {
  const HomeTab({
    super.key,
    required this.onGoToPersonal,
    required this.onGoToPension,
  });

  final VoidCallback onGoToPersonal;
  final VoidCallback onGoToPension;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(personalCycleSummaryProvider);
    final pensionAsync = ref.watch(currentPensionMonthProvider);
    final cycle = ref.watch(currentPersonalCycleProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'מבט על',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
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
                color: Colors.blue.shade50,
                child: InkWell(
                  onTap: onGoToPersonal,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'הוצאות אישיות',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${summary.totalSpent.toStringAsFixed(0)} / ${summary.budget > 0 ? summary.budget.toStringAsFixed(0) : "—"} ₪',
                          style: theme.textTheme.titleSmall,
                        ),
                        if (summary.budget > 0) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (summary.totalSpent / summary.budget)
                                  .clamp(0.0, 2.0),
                              minHeight: 10,
                              backgroundColor: theme.colorScheme.surfaceVariant
                                  .withOpacity(0.3),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(barColor),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'מחזור: ${cycle.start.day}.${cycle.start.month}.${cycle.start.year} – ${cycle.end.day}.${cycle.end.month}.${cycle.end.year}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'לחץ למעבר להוצאות אישיות',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
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
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('שגיאה: $e'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          pensionAsync.when(
            data: (month) {
              final theme = Theme.of(context);
              final net = month?.netProfit ?? 0.0;
              final netColor = net >= 0 ? Colors.green : Colors.red;
              return Card(
                color: Colors.green.shade50,
                child: InkWell(
                  onTap: onGoToPension,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pets, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'פנסיון – חודש נוכחי',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (month != null) ...[
                          Text(
                            'ברוטו: ${month.grossIncome.toStringAsFixed(0)} ₪',
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            'הוצאות: ${month.totalExpenses.toStringAsFixed(0)} ₪',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'רווח נטו: ${net.toStringAsFixed(0)} ₪',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: netColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else
                          Text(
                            'טרם הוזנו נתונים לחודש זה',
                            style: theme.textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'לחץ למעבר לפנסיון',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
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
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('שגיאה: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
