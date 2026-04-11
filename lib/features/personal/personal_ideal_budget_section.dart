import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/personal/ideal_budget_logic.dart';

/// בלוק התפלגות אידיאלית לפי קטגוריה (מתחת לסרגל התקרה הכללי).
class PersonalIdealDistributionBlock extends StatelessWidget {
  const PersonalIdealDistributionBlock({super.key, required this.ideal});

  final IdealBudgetSnapshot ideal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'התפלגות אידיאלית (הוראות קבע + ממוצע 6 מחזורים)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'סכום הוראות הקבע (קבוע במחזור): '
          '${ideal.totalFixedRecurring.toStringAsFixed(0)} ₪',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'נשאר לחלוקה גמישה לפי היסטוריה: '
          '${ideal.flexiblePool.toStringAsFixed(0)} ₪',
          style: theme.textTheme.bodyMedium,
        ),
        if (ideal.totalFixedRecurring > ideal.budget && ideal.budget > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'שים לב: סכום הוראות הקבע עולה על תקרת התקציב.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (ideal.pastCyclesUsedForAverage < 6 && ideal.pastCyclesUsedForAverage > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'הממוצע מבוסס על ${ideal.pastCyclesUsedForAverage} מחזורים '
              '(מחזורים בלי הוצאות גמישות מחוץ להוראות קבע לא נספרים).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        if (ideal.pastCyclesUsedForAverage == 0 && ideal.budget > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'אין עדיין מספיק היסטוריה לחלוקה גמישה – קטגוריות חדשות יקבלו 0 '
              'עד שיופיעו נתונים במחזורים קודמים.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        const SizedBox(height: 16),
        _IdealDistributionPie(ideal: ideal),
        const SizedBox(height: 16),
        for (final row in ideal.categories)
          if (row.idealTotal > 0.01 ||
              row.fixedFromRecurring > 0.01 ||
              row.spentCurrent > 0.01)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryIdealRow(row: row),
            ),
      ],
    );
  }
}

class _IdealDistributionPie extends StatelessWidget {
  const _IdealDistributionPie({required this.ideal});

  final IdealBudgetSnapshot ideal;

  static const _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.cyan,
    Colors.teal,
    Colors.indigo,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slices =
        ideal.categories.where((c) => c.idealTotal > 0.01).toList();
    if (slices.isEmpty) {
      return const SizedBox.shrink();
    }

    final sumIdeal =
        slices.fold<double>(0, (a, b) => a + b.idealTotal);
    final denom =
        ideal.budget > 0.01 ? ideal.budget : (sumIdeal > 0 ? sumIdeal : 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'התפלגות אידיאלית לפי קטגוריה (אחוזים)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ideal.budget > 0.01
              ? 'האחוזים מחושבים מול תקציב המחזור (${ideal.budget.toStringAsFixed(0)} ₪)'
              : 'האחוזים מחושבים מסך יעדי הקטגוריות',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: [
                for (var i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    color: _colors[i % _colors.length],
                    value: slices[i].idealTotal,
                    title:
                        '${(slices[i].idealTotal / denom * 100).clamp(0, 999).toStringAsFixed(0)}%',
                    radius: 68,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (var i = 0; i < slices.length; i++)
              Chip(
                avatar: CircleAvatar(
                  backgroundColor: _colors[i % _colors.length],
                  radius: 6,
                ),
                label: Text(
                  '${slices[i].categoryName}: '
                  '${(slices[i].idealTotal / denom * 100).toStringAsFixed(1)}% '
                  '(${slices[i].idealTotal.toStringAsFixed(0)} ₪)',
                  style: theme.textTheme.bodySmall,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryIdealRow extends StatelessWidget {
  const _CategoryIdealRow({required this.row});

  final CategoryBudgetIdeal row;

  Color _barColor(ThemeData theme) {
    if (row.idealTotal <= 0.01) {
      return theme.colorScheme.outlineVariant;
    }
    final r = row.ratioToIdeal;
    if (r <= 0.85) return Colors.green.shade600;
    if (r <= 1.0) return Colors.orange.shade700;
    return theme.colorScheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasIdeal = row.idealTotal > 0.01;
    final ratio =
        hasIdeal ? (row.spentCurrent / row.idealTotal).clamp(0.0, 2.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.categoryName,
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (row.isOverIdeal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'חריגה',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          hasIdeal
              ? 'נוצל ${row.spentCurrent.toStringAsFixed(0)} ₪ '
                  'מתוך יעד ${row.idealTotal.toStringAsFixed(0)} ₪'
              : 'נוצל ${row.spentCurrent.toStringAsFixed(0)} ₪ (אין יעד מהיסטוריה)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: row.isOverIdeal ? theme.colorScheme.error : null,
            fontWeight: row.isOverIdeal ? FontWeight.w600 : null,
          ),
        ),
        if (row.fixedFromRecurring > 0.01)
          Text(
            'מתוכם הוראות קבע: ${row.fixedFromRecurring.toStringAsFixed(0)} ₪',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: hasIdeal ? ratio.clamp(0, 2) : null,
            minHeight: 8,
            backgroundColor:
                theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
            valueColor: AlwaysStoppedAnimation<Color>(_barColor(theme)),
          ),
        ),
      ],
    );
  }
}
