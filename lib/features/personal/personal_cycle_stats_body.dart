import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/models/personal_models.dart';

/// גרף עוגה + פירוט לפי קטגוריות למחזור נתון (משותף למסך סטטיסטיקה ולהיסטוריה).
class PersonalCycleStatsBody extends StatelessWidget {
  const PersonalCycleStatsBody({
    super.key,
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

    if (expenses.isEmpty || categories.isEmpty) {
      return const Center(
        child: Text('אין מספיק נתונים להצגת התפלגות.'),
      );
    }

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
                    entries[i],
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
              final category = categories.firstWhere(
                (c) => c.id == entry.key,
                orElse: () => PersonalCategory(
                  id: entry.key,
                  userId: '',
                  name: 'קטגוריה לא ידועה',
                  iconName: 'category',
                ),
              );
              final pct = total == 0 ? 0 : (entry.value / total * 100);
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: colors[index % colors.length],
                  child: Icon(
                    PersonalCategory.iconDataFromName(category.iconName),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                title: Text(category.name),
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
    MapEntry<String, double> entry,
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
