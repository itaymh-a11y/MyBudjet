import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/date_helpers.dart';
import '../../core/models/personal_models.dart';
import '../../core/repositories/providers.dart';

class PersonalStatsScreen extends ConsumerWidget {
  const PersonalStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(personalExpensesForCurrentCycleProvider);
    final categoriesAsync = ref.watch(personalCategoriesProvider);
    final cycle = ref.watch(currentPersonalCycleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('סטטיסטיקה אישית'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'מחזור: ${cycle.start.day}.${cycle.start.month}.${cycle.start.year}'
                ' - ${cycle.end.day}.${cycle.end.month}.${cycle.end.year}',
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: expensesAsync.when(
                data: (expenses) {
                  return categoriesAsync.when(
                    data: (categories) {
                      if (expenses.isEmpty || categories.isEmpty) {
                        return const Center(
                          child: Text('אין מספיק נתונים להצגת סטטיסטיקה.'),
                        );
                      }
                      return _StatsContent(
                        expenses: expenses,
                        categories: categories,
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Center(child: Text('שגיאה בטעינת קטגוריות: $e')),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('שגיאה בטעינת הוצאות: $e')),
              ),
            ),
            const SizedBox(height: 16),
            const _CyclesBarChart(),
          ],
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({
    required this.expenses,
    required this.categories,
  });

  final List<PersonalExpense> expenses;
  final List<PersonalCategory> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    final Map<String, double> byCategory = {};
    for (final e in expenses) {
      byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + e.amount;
    }

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.cyan,
      Colors.teal,
    ];

    return Column(
      children: [
        Text(
          'סה״כ הוצאות במחזור: ${total.toStringAsFixed(0)} ₪',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  _buildPieSection(
                    i,
                    entries[i],
                    categories,
                    colors[i % colors.length],
                    total,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final categoryName = categories
                      .firstWhere(
                        (c) => c.id == entry.key,
                        orElse: () => PersonalCategory(
                          id: entry.key,
                          name: 'קטגוריה לא ידועה',
                        ),
                      )
                      .name;
              final pct = total == 0 ? 0 : (entry.value / total * 100);
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: colors[index % colors.length],
                ),
                title: Text(categoryName),
                subtitle: Text('${pct.toStringAsFixed(1)}%'),
                trailing: Text('${entry.value.toStringAsFixed(0)} ₪'),
              );
            },
          ),
        ),
      ],
    );
  }

  PieChartSectionData _buildPieSection(
    int index,
    MapEntry<String, double> entry,
    List<PersonalCategory> categories,
    Color color,
    double total,
  ) {
    final pct = total == 0 ? 0 : (entry.value / total * 100);
    final title = '${pct.toStringAsFixed(0)}%';
    return PieChartSectionData(
      color: color,
      value: entry.value,
      title: title,
      radius: 60,
      titleStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _CyclesBarChart extends ConsumerWidget {
  const _CyclesBarChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(firebaseAuthProvider);
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<List<PersonalCycleRange>>(
      future: _loadRecentCycles(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final cycles = snapshot.data!;
        if (cycles.isEmpty) {
          return const SizedBox(
            height: 150,
            child: Center(child: Text('אין מחזורים נוספים להשוואה.')),
          );
        }

        return SizedBox(
          height: 180,
          child: FutureBuilder<List<double>>(
            future: _loadTotalsForCycles(ref, user.uid, cycles),
            builder: (context, snapshotTotals) {
              if (!snapshotTotals.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final totals = snapshotTotals.data!;
              if (totals.isEmpty) {
                return const Center(
                  child: Text('אין נתוני הוצאות למחזורים קודמים.'),
                );
              }

              final maxY =
                  totals.fold<double>(0, (max, v) => v > max ? v : max) * 1.2;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('השוואת מחזורים אחרונים'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= cycles.length) {
                                  return const SizedBox.shrink();
                                }
                                final c = cycles[index];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${c.start.month}/${c.start.year % 100}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < totals.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: totals[i],
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  width: 14,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                        ],
                        maxY: maxY == 0 ? 100 : maxY,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<List<PersonalCycleRange>> _loadRecentCycles() async {
    final now = DateTime.now();
    final List<PersonalCycleRange> cycles = [];
    DateTime cursor = now;
    for (var i = 0; i < 6; i++) {
      final range = currentPersonalCycle(cursor);
      cycles.add(range);
      cursor = range.start.subtract(const Duration(days: 1));
    }
    return cycles.reversed.toList();
  }

  Future<List<double>> _loadTotalsForCycles(
    WidgetRef ref,
    String userId,
    List<PersonalCycleRange> cycles,
  ) async {
    final repo = ref.read(personalRepositoryProvider);
    final List<double> totals = [];
    for (final c in cycles) {
      final expenses = await repo.getExpensesForRange(
        userId: userId,
        start: c.start,
        end: c.end,
      );
      final total =
          expenses.fold<double>(0, (sum, e) => sum + e.amount);
      totals.add(total);
    }
    return totals;
  }
}

