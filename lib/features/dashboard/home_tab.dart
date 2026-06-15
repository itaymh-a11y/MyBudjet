import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/business_professions.dart';
import '../../core/repositories/providers.dart';

/// מסך בית – תצוגת סיכום: Progress Bar אישי + כרטיס עסקי + קישורים מהירים.
class HomeTab extends ConsumerWidget {
  const HomeTab({
    super.key,
    required this.onGoToPersonal,
    required this.onGoToPension,
    required this.onGoToSavings,
  });

  final VoidCallback onGoToPersonal;
  final VoidCallback onGoToPension;
  final VoidCallback onGoToSavings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(personalCycleSummaryProvider);
    final pensionAsync = ref.watch(currentPensionMonthProvider);
    final savingsKey = ref.watch(currentPensionMonthKeyProvider);
    final savingsMonthAsync = ref.watch(savingsMonthEntryProvider(savingsKey));
    final cycle = ref.watch(currentPersonalCycleProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final businessTabName = userProfileAsync.maybeWhen(
      data: (profile) {
        final value = profile?.businessTabName.trim();
        if (value == null || value.isEmpty) return 'הכנסות';
        return value;
      },
      orElse: () => 'הכנסות',
    );
    final businessIconName = userProfileAsync.maybeWhen(
      data: (profile) => profile?.businessIconName,
      orElse: () => BusinessProfessionCatalog.defaultIconName,
    );
    final userType = userProfileAsync.maybeWhen(
      data: (profile) => profile?.userType ?? 'selfEmployed',
      orElse: () => 'selfEmployed',
    );
    final isStudent = userType == 'student';
    final scholarshipsAsync =
        isStudent ? ref.watch(scholarshipEntriesProvider) : null;

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
                              backgroundColor: theme.colorScheme.surfaceContainerHighest
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
                            Icon(
                              BusinessProfessionCatalog.iconFromName(
                                businessIconName,
                              ),
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isStudent
                                  ? 'הכנסות מעבודה – חודש נוכחי'
                                  : '$businessTabName – חודש נוכחי',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (month != null) ...[
                          if (isStudent && month.incomeSourceSnapshots.isNotEmpty)
                            for (final source in month.incomeSourceSnapshots)
                              Text(
                                source.hours > 0
                                    ? '${source.name}: ${source.hours.toStringAsFixed(1)} שע׳ • ${source.amount.toStringAsFixed(0)} ₪'
                                    : '${source.name}: ${source.amount.toStringAsFixed(0)} ₪',
                                style: theme.textTheme.bodySmall,
                              ),
                          Text(
                            isStudent
                                ? 'ברוטו מעבודה: ${month.grossIncome.toStringAsFixed(0)} ₪'
                                : 'ברוטו: ${month.grossIncome.toStringAsFixed(0)} ₪',
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (month.fixedMonthlySnapshots.isNotEmpty)
                            for (final line in month.fixedMonthlySnapshots)
                              Text(
                                line.isAddition
                                    ? '${line.name}: +${line.amount.toStringAsFixed(0)} ₪'
                                    : '${line.name}: −${line.amount.toStringAsFixed(0)} ₪',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: line.isAddition
                                      ? Colors.green.shade700
                                      : null,
                                ),
                              )
                          else ...[
                            if (month.totalFixedAdditions > 0)
                              Text(
                                'תוספות קבועות: +${month.totalFixedAdditions.toStringAsFixed(0)} ₪',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green.shade700,
                                ),
                              ),
                            if (month.totalFixedExpenses > 0)
                              Text(
                                'הוצאות קבועות: −${month.totalFixedExpenses.toStringAsFixed(0)} ₪',
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                          if (month.grossDeductionSnapshots.isNotEmpty)
                            for (final line in month.grossDeductionSnapshots)
                              Text(
                                '${line.name}: −${line.amount.toStringAsFixed(0)} ₪',
                                style: theme.textTheme.bodySmall,
                              )
                          else if (month.totalGrossDeductions > 0)
                            Text(
                              'הורדות מהברוטו: −${month.totalGrossDeductions.toStringAsFixed(0)} ₪',
                              style: theme.textTheme.bodySmall,
                            ),
                          if (month.totalExpenses > 0)
                            Text(
                              'הוצאות: ${month.totalExpenses.toStringAsFixed(0)} ₪',
                              style: theme.textTheme.bodyMedium,
                            ),
                          const SizedBox(height: 8),
                          Text(
                            isStudent
                                ? 'נטו מעבודה (בסיס חיסכון): ${net.toStringAsFixed(0)} ₪'
                                : 'רווח נטו: ${net.toStringAsFixed(0)} ₪',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: netColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isStudent && scholarshipsAsync != null) ...[
                            const SizedBox(height: 12),
                            scholarshipsAsync.when(
                              data: (entries) {
                                if (entries.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final scholarshipTotal = entries.fold<double>(
                                  0,
                                  (sum, entry) => sum + entry.amount,
                                );
                                final next = entries.firstWhere(
                                  (entry) {
                                    final now = DateTime.now();
                                    return entry.expectedYear > now.year ||
                                        (entry.expectedYear == now.year &&
                                            entry.expectedMonth >= now.month);
                                  },
                                  orElse: () => entries.last,
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'מלגות רשומות: ${entries.length} • '
                                      '${scholarshipTotal.toStringAsFixed(0)} ₪ שנתי',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'קבלה צפויה הבאה: ${next.expectedMonthLabel}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ],
                        ] else
                          Text(
                            'טרם הוזנו נתונים לחודש זה',
                            style: theme.textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'לחץ למעבר ל$businessTabName',
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
          const SizedBox(height: 16),
          savingsMonthAsync.when(
            data: (entry) {
              final theme = Theme.of(context);
              return Card(
                color: Colors.amber.shade50,
                child: InkWell(
                  onTap: onGoToSavings,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.savings_outlined,
                                color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Text(
                              'תוכנית חיסכון – חודש נוכחי',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (entry != null) ...[
                          Text(
                            'יעד הפקדה: ${entry.targetAmount.toStringAsFixed(0)} ₪',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.deposited
                                ? 'סומן: בוצעה הפקדה'
                                : 'טרם סומן ביצוע הפקדה',
                            style: theme.textTheme.bodySmall,
                          ),
                        ] else
                          Text(
                            'לאחר שמירת נתונים ב$businessTabName יחושב היעד אוטומטית',
                            style: theme.textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'לחץ למעבר לתוכנית החיסכון',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.amber.shade900,
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
                child: Text('שגיאה בחיסכון: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
