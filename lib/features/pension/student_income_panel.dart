import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/date_helpers.dart';
import '../../core/models/pension_models.dart';
import '../../core/models/student_models.dart';
import '../../core/models/user_model.dart';
import '../../core/repositories/providers.dart';

class StudentIncomePanel extends ConsumerStatefulWidget {
  const StudentIncomePanel({
    super.key,
    required this.selectedKey,
  });

  final PensionMonthKey selectedKey;

  @override
  ConsumerState<StudentIncomePanel> createState() => _StudentIncomePanelState();
}

class _StudentIncomePanelState extends ConsumerState<StudentIncomePanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _pieColors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'עבודות'),
            Tab(text: 'מלגות'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _JobsTab(selectedKey: widget.selectedKey, pieColors: _pieColors),
              const _ScholarshipsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _JobsTab extends ConsumerWidget {
  const _JobsTab({
    required this.selectedKey,
    required this.pieColors,
  });

  final PensionMonthKey selectedKey;
  final List<Color> pieColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final logsAsync = ref.watch(incomeWorkLogsForMonthProvider(selectedKey));
    final theme = Theme.of(context);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('לא נמצא פרופיל משתמש'));
        }
        final sources =
            profile.incomeSources.where((source) => source.isActive).toList();
        final logs = logsAsync.maybeWhen(
          data: (value) => value,
          orElse: () => const <IncomeWorkLog>[],
        );
        final totals = computeStudentWorkMonth(
          sources: profile.incomeSources,
          logs: logs,
          deductions: profile.grossDeductions,
          fixedItems: profile.fixedMonthlyItems,
        );
        final netColor = totals.net >= 0 ? Colors.green : Colors.red;

        return ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          children: [
            if (sources.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'עדיין לא הוגדרו מקורות הכנסה.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'הוסיפי מקורות הכנסה (בייביסיטר, חונכות וכו\') בהגדרות החשבון.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            for (final source in sources)
              _SourceCard(
                source: source,
                logs: logs.where((log) => log.sourceId == source.id).toList(),
                selectedKey: selectedKey,
                onChanged: () => _syncStudentMonth(ref, selectedKey),
              ),
            if (totals.sourceSnapshots.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'התפלגות הכנסות מעבודה',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _WorkPieChartWithLegend(
                        snapshots: totals.sourceSnapshots,
                        colors: pieColors,
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < totals.sourceSnapshots.length; i++)
                        _SourceBreakdownRow(
                          snapshot: totals.sourceSnapshots[i],
                          color: pieColors[i % pieColors.length],
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Card(
              color: netColor.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'סיכום עבודה לחודש (ללא מלגות)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _summaryRow('ברוטו מעבודה', totals.gross),
                    if (totals.totalDeductions > 0)
                      _summaryRow('הורדות', -totals.totalDeductions, muted: true),
                    if (totals.totalExpenses > 0)
                      _summaryRow('הוצאות קבועות', -totals.totalExpenses, muted: true),
                    const Divider(height: 16),
                    _summaryRow(
                      'נטו מעבודה (בסיס חיסכון)',
                      totals.net,
                      bold: true,
                      color: netColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: sources.isEmpty
                  ? null
                  : () => _saveStudentMonth(ref, selectedKey, profile, logs),
              child: const Text('שמור נתוני עבודה לחודש'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('שגיאה: $error')),
    );
  }

  Widget _summaryRow(
    String label,
    double amount, {
    bool muted = false,
    bool bold = false,
    Color? color,
  }) {
    final prefix = amount < 0 ? '−' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              color: muted ? Colors.grey.shade700 : null,
            ),
          ),
          Text(
            '$prefix${amount.abs().toStringAsFixed(0)} ₪',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncStudentMonth(WidgetRef ref, PensionMonthKey key) async {
    final profile = await ref.read(currentUserProfileProvider.future);
    if (profile == null || profile.userType != 'student') return;
    final logs = await ref.read(incomeWorkLogsForMonthProvider(key).future);
    await _saveStudentMonth(ref, key, profile, logs);
  }

  Future<void> _saveStudentMonth(
    WidgetRef ref,
    PensionMonthKey key,
    UserModel profile,
    List<IncomeWorkLog> logs,
  ) async {
    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;

    final totals = computeStudentWorkMonth(
      sources: profile.incomeSources,
      logs: logs,
      deductions: profile.grossDeductions,
      fixedItems: profile.fixedMonthlyItems,
    );

    final month = PensionMonth(
      id: '${key.year}-${key.month.toString().padLeft(2, '0')}',
      userId: auth.uid,
      year: key.year,
      month: key.month,
      grossIncome: totals.gross,
      totalGrossDeductions: totals.totalDeductions,
      grossDeductionSnapshots: totals.deductionSnapshots,
      totalFixedAdditions: totals.totalFixedAdditions,
      totalFixedExpenses: totals.totalFixedExpenses,
      fixedMonthlySnapshots: totals.fixedMonthlySnapshots,
      incomeSourceSnapshots: totals.sourceSnapshots,
      totalExpenses: totals.totalExpenses,
      netProfit: totals.net,
    );

    await ref.read(pensionRepositoryProvider).upsertMonth(auth.uid, month);
    await ref.read(savingsRepositoryProvider).syncFromPensionNet(
          userId: auth.uid,
          year: key.year,
          month: key.month,
          netProfit: totals.net,
        );

    ref.invalidate(pensionMonthForProvider(key));
    ref.invalidate(currentPensionMonthProvider);
    ref.invalidate(recentPensionMonthsProvider(12));
    ref.invalidate(savingsMonthEntryProvider(key));
    ref.invalidate(recentSavingsMonthsProvider(48));
  }
}

class _SourceCard extends ConsumerWidget {
  const _SourceCard({
    required this.source,
    required this.logs,
    required this.selectedKey,
    required this.onChanged,
  });

  final IncomeSource source;
  final List<IncomeWorkLog> logs;
  final PensionMonthKey selectedKey;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = logs.fold<double>(0, (sum, log) => sum + log.hours);
    final amount = logs.fold<double>(0, (sum, log) => sum + log.amount);
    final displayAmount =
        source.isFixedMonthly ? source.fixedMonthlyAmount : amount;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  child: Icon(incomeSourceIconFromName(source.iconName), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        source.isHourly
                            ? '${source.hourlyRate.toStringAsFixed(0)} ₪ לשעה'
                            : '${source.fixedMonthlyAmount.toStringAsFixed(0)} ₪ קבוע לחודש',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${displayAmount.toStringAsFixed(0)} ₪',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (source.isHourly) ...[
              const SizedBox(height: 8),
              Text(
                'שעות במחזור: ${hours.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: source.hourlyRate <= 0
                      ? null
                      : () => _openAddHoursDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('הוספת שעות'),
                ),
              ),
              if (logs.isEmpty)
                Text(
                  'אין רשומות שעות למחזור זה',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              for (final log in logs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${log.hours.toStringAsFixed(2)} שעות'),
                  subtitle: Text(
                    '${log.date.day}.${log.date.month}.${log.date.year} • '
                    '${log.amount.toStringAsFixed(0)} ₪',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteLog(ref, log.id),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openAddHoursDialog(BuildContext context, WidgetRef ref) async {
    final hoursController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('הוספת שעות – ${source.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hoursController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'כמות שעות',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('תאריך'),
                subtitle: Text(
                  '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setLocalState(() => selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ביטול'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('שמירה'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      hoursController.dispose();
      return;
    }

    final hours = double.tryParse(
          hoursController.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    hoursController.dispose();
    if (hours <= 0) return;

    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;

    final amount = hours * source.hourlyRate;
    await ref.read(studentIncomeRepositoryProvider).addWorkLog(
          auth.uid,
          IncomeWorkLog(
            id: '',
            userId: auth.uid,
            sourceId: source.id,
            date: selectedDate,
            hours: hours,
            rateSnapshot: source.hourlyRate,
            amount: amount,
            createdAt: DateTime.now(),
          ),
        );

    ref.invalidate(incomeWorkLogsForMonthProvider(selectedKey));
    onChanged();
  }

  Future<void> _deleteLog(WidgetRef ref, String entryId) async {
    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;
    await ref.read(studentIncomeRepositoryProvider).deleteWorkLog(
          auth.uid,
          entryId,
        );
    ref.invalidate(incomeWorkLogsForMonthProvider(selectedKey));
    onChanged();
  }
}

class _WorkPieChartWithLegend extends StatelessWidget {
  const _WorkPieChartWithLegend({
    required this.snapshots,
    required this.colors,
  });

  final List<IncomeSourceMonthSnapshot> snapshots;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final total = snapshots.fold<double>(0, (sum, item) => sum + item.amount);
    if (total <= 0) {
      return const Center(child: Text('אין נתונים להצגה'));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (var i = 0; i < snapshots.length; i++)
                  PieChartSectionData(
                    color: colors[i % colors.length],
                    value: snapshots[i].amount,
                    title: '${((snapshots[i].amount / total) * 100).round()}%',
                    radius: 48,
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'מקרא',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < snapshots.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          snapshots[i].name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${((snapshots[i].amount / total) * 100).round()}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceBreakdownRow extends StatelessWidget {
  const _SourceBreakdownRow({
    required this.snapshot,
    required this.color,
  });

  final IncomeSourceMonthSnapshot snapshot;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              snapshot.hours > 0
                  ? '${snapshot.name}: ${snapshot.hours.toStringAsFixed(1)} שעות'
                  : snapshot.name,
            ),
          ),
          Text(
            '${snapshot.amount.toStringAsFixed(0)} ₪',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ScholarshipsTab extends ConsumerWidget {
  const _ScholarshipsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scholarshipsAsync = ref.watch(scholarshipEntriesProvider);
    final theme = Theme.of(context);

    return scholarshipsAsync.when(
      data: (entries) {
        final total =
            entries.fold<double>(0, (sum, entry) => sum + entry.amount);
        return ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          children: [
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'המלגות שלי',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${entries.length} מלגות • ${total.toStringAsFixed(0)} ₪ סה״כ שנתי',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ריכוז שנתי של המלגות שאליהן נרשמת. '
                      'מלגות אינן קשורות למחזור הכנסות ולא נכללות בחישוב החיסכון.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _openAddScholarshipDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('הוספת מלגה'),
              ),
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('אין מלגות רשומות. הוסיפי מלגה כדי לעקוב אחרי קבלה צפויה.'),
              ),
            for (final entry in entries)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'קבלה צפויה: ${entry.expectedMonthLabel}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                if (scholarshipClassificationLabel(
                                        entry.classification) !=
                                    null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'סיווג: ${scholarshipClassificationLabel(entry.classification)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                if (entry.isVolunteer &&
                                    entry.requiredVolunteerHours != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'שעות התנדבות נדרשות: '
                                    '${entry.requiredVolunteerHours!.toStringAsFixed(0)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                if (entry.volunteerHourlyValue != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'שווי לשעה: '
                                    '${entry.volunteerHourlyValue!.toStringAsFixed(2)} ₪',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${entry.amount.toStringAsFixed(0)} ₪',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    _deleteScholarship(ref, entry.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('שגיאה: $error')),
    );
  }

  Future<void> _openAddScholarshipDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final volunteerHoursController = TextEditingController();
    final now = DateTime.now();
    var selectedMonth = now.month;
    var selectedYear = now.year;
    String? classification;

    double? previewHourlyValue() {
      if (classification != 'volunteer') return null;
      final amount = double.tryParse(
            amountController.text.trim().replaceAll(',', '.'),
          ) ??
          0;
      final hours = double.tryParse(
            volunteerHoursController.text.trim().replaceAll(',', '.'),
          ) ??
          0;
      if (amount <= 0 || hours <= 0) return null;
      return amount / hours;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final hourlyValue = previewHourlyValue();
          return AlertDialog(
            title: const Text('הוספת מלגה'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'שם המלגה',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setLocalState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'סכום המלגה (₪)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'חודש קבלה צפוי',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (var month = 1; month <= 12; month++)
                          DropdownMenuItem<int>(
                            value: month,
                            child: Text(hebrewMonthNames[month]),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => selectedMonth = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'שנת קבלה צפויה',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (var year = now.year - 1; year <= now.year + 5; year++)
                          DropdownMenuItem<int>(
                            value: year,
                            child: Text('$year'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => selectedYear = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: classification,
                      decoration: const InputDecoration(
                        labelText: 'סיווג מלגה (אופציונלי)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('ללא סיווג'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'entitlement',
                          child: Text('זכאות'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'volunteer',
                          child: Text('התנדבותית'),
                        ),
                      ],
                      onChanged: (value) {
                        setLocalState(() {
                          classification = value;
                          if (value != 'volunteer') {
                            volunteerHoursController.clear();
                          }
                        });
                      },
                    ),
                    if (classification == 'volunteer') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: volunteerHoursController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setLocalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'שעות התנדבות נדרשות למלגה',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (hourlyValue != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'שווי המלגה לשעה: ${hourlyValue.toStringAsFixed(2)} ₪',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ביטול'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('שמירה'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) {
      nameController.dispose();
      amountController.dispose();
      volunteerHoursController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final amount = double.tryParse(
          amountController.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    final volunteerHours = classification == 'volunteer'
        ? double.tryParse(
            volunteerHoursController.text.trim().replaceAll(',', '.'),
          )
        : null;
    nameController.dispose();
    amountController.dispose();
    volunteerHoursController.dispose();

    if (name.isEmpty || amount <= 0) return;
    if (classification == 'volunteer' &&
        (volunteerHours == null || volunteerHours <= 0)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('למלגה התנדבותית יש להזין שעות התנדבות נדרשות'),
          ),
        );
      }
      return;
    }

    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;

    await ref.read(studentIncomeRepositoryProvider).addScholarship(
          auth.uid,
          ScholarshipEntry(
            id: '',
            userId: auth.uid,
            name: name,
            amount: amount,
            expectedYear: selectedYear,
            expectedMonth: selectedMonth,
            classification: classification,
            requiredVolunteerHours: volunteerHours,
            createdAt: DateTime.now(),
          ),
        );

    ref.invalidate(scholarshipEntriesProvider);
  }

  Future<void> _deleteScholarship(WidgetRef ref, String entryId) async {
    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;
    await ref.read(studentIncomeRepositoryProvider).deleteScholarship(
          auth.uid,
          entryId,
        );
    ref.invalidate(scholarshipEntriesProvider);
  }
}
