import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/business_professions.dart';
import '../../core/models/fixed_monthly_models.dart';
import '../../core/models/gross_deduction_models.dart';
import '../../core/models/pension_models.dart';
import '../../core/models/date_helpers.dart';
import '../../core/repositories/providers.dart';
import 'student_income_panel.dart';

class PensionScreen extends ConsumerStatefulWidget {
  const PensionScreen({super.key});

  @override
  ConsumerState<PensionScreen> createState() => _PensionScreenState();
}

class _PensionScreenState extends ConsumerState<PensionScreen> {
  final _grossController = TextEditingController();
  final _expensesController = TextEditingController();

  /// החודש/שנה שנבחרו להצגה ועריכה (ברירת מחדל: חודש נוכחי).
  int? _selectedYear;
  int? _selectedMonth;
  PensionMonthKey? _lastAppliedKey;

  @override
  void initState() {
    super.initState();
    final key = ref.read(currentPensionMonthKeyProvider);
    _selectedYear = key.year;
    _selectedMonth = key.month;
  }

  @override
  void dispose() {
    _grossController.dispose();
    _expensesController.dispose();
    super.dispose();
  }

  PensionMonthKey get _selectedKey =>
      PensionMonthKey(year: _selectedYear!, month: _selectedMonth!);

  void _goToCurrentMonth() {
    final key = ref.read(currentPensionMonthKeyProvider);
    setState(() {
      _selectedYear = key.year;
      _selectedMonth = key.month;
    });
  }

  void _goToPrevMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear = _selectedYear! - 1;
      } else {
        _selectedMonth = _selectedMonth! - 1;
      }
    });
  }

  void _goToNextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear = _selectedYear! + 1;
      } else {
        _selectedMonth = _selectedMonth! + 1;
      }
    });
  }

  Future<void> _openChartFullscreen() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'סגור',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'השוואת חודשים – תצוגה מלאה',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Expanded(child: _PensionBarChart(compact: false)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static const _monthNames = [
    '', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
    'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר',
  ];

  @override
  Widget build(BuildContext context) {
    final selectedKey = _selectedKey;
    final monthAsync = ref.watch(pensionMonthForProvider(selectedKey));
    final workHoursAsync = ref.watch(workHoursForMonthProvider(selectedKey));
    final businessIncomeEntriesAsync =
        ref.watch(businessIncomeEntriesForMonthProvider(selectedKey));
    final businessExpenseEntriesAsync =
        ref.watch(businessExpenseEntriesForMonthProvider(selectedKey));
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final userType = userProfileAsync.maybeWhen(
      data: (profile) => profile?.userType ?? 'selfEmployed',
      orElse: () => 'selfEmployed',
    );
    final employeeCompensationType = userProfileAsync.maybeWhen(
      data: (profile) => profile?.employeeCompensationType ?? 'fixed',
      orElse: () => 'fixed',
    );
    final employeeFixedSalary = userProfileAsync.maybeWhen(
      data: (profile) => profile?.employeeFixedMonthlySalary ?? 0.0,
      orElse: () => 0.0,
    );
    final employeeHourlyRate = userProfileAsync.maybeWhen(
      data: (profile) => profile?.employeeHourlyRate ?? 0.0,
      orElse: () => 0.0,
    );
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
    final isStudent = userType == 'student';
    final isSelfEmployed = userType == 'selfEmployed';
    final selfEmployedManualIncomeEntries = userProfileAsync.maybeWhen(
      data: (profile) => profile?.selfEmployedManualIncomeEntries ?? false,
      orElse: () => false,
    );
    final selfEmployedManualExpenseEntries = userProfileAsync.maybeWhen(
      data: (profile) => profile?.selfEmployedManualExpenseEntries ?? false,
      orElse: () => false,
    );
    final grossDeductions = userProfileAsync.maybeWhen(
      data: (profile) => profile?.grossDeductions ?? const [],
      orElse: () => const <FixedGrossDeduction>[],
    );
    final fixedMonthlyItems = userProfileAsync.maybeWhen(
      data: (profile) => profile?.fixedMonthlyItems ?? const [],
      orElse: () => const <FixedMonthlyItem>[],
    );
    final activeFixedAdditions = fixedAdditions(fixedMonthlyItems);
    final activeFixedExpenses = fixedExpenses(fixedMonthlyItems);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(BusinessProfessionCatalog.iconFromName(businessIconName)),
            const SizedBox(width: 8),
            Text(businessTabName),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _goToNextMonth,
                      tooltip: 'חודש הבא',
                    ),
                    Column(
                      children: [
                        Text(
                          '${_monthNames[_selectedMonth!]} $_selectedYear',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        TextButton.icon(
                          onPressed: _goToCurrentMonth,
                          icon: const Icon(Icons.today, size: 18),
                          label: const Text('חודש נוכחי'),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _goToPrevMonth,
                      tooltip: 'חודש קודם',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isStudent
                  ? StudentIncomePanel(selectedKey: selectedKey)
                  : ListView(
                children: [
                  monthAsync.when(
                    data: (month) {
                      if (_lastAppliedKey != selectedKey) {
                        _lastAppliedKey = selectedKey;
                        if (userType == 'selfEmployed') {
                          if (!selfEmployedManualIncomeEntries) {
                            if (month != null) {
                              _grossController.text =
                                  month.grossIncome.toStringAsFixed(0);
                            } else {
                              _grossController.clear();
                            }
                          }
                          if (!selfEmployedManualExpenseEntries) {
                            if (month != null) {
                              _expensesController.text =
                                  month.totalExpenses.toStringAsFixed(0);
                            } else {
                              _expensesController.clear();
                            }
                          }
                        }
                      }
                      final parsedGross = _parseController(_grossController);
                      final parsedExpenses = _parseController(_expensesController);
                      final businessIncomeEntries = businessIncomeEntriesAsync
                          .maybeWhen(
                            data: (list) => list,
                            orElse: () => const <BusinessIncomeEntry>[],
                          );
                      final businessExpenseEntries = businessExpenseEntriesAsync
                          .maybeWhen(
                            data: (list) => list,
                            orElse: () => const <BusinessExpenseEntry>[],
                          );
                      final manualIncomeGross = businessIncomeEntries.fold<double>(
                        0,
                        (sum, e) => sum + e.amount,
                      );
                      final manualExpenseTotal =
                          businessExpenseEntries.fold<double>(
                        0,
                        (sum, e) => sum + e.amount,
                      );
                      final hourlyEntries = workHoursAsync.maybeWhen(
                        data: (list) => list,
                        orElse: () => const <WorkHoursEntry>[],
                      );
                      final hourlyGross = hourlyEntries.fold<double>(
                        0,
                        (sum, e) => sum + (e.hours * e.hourlyRateSnapshot),
                      );
                      final grossBase = userType == 'selfEmployed'
                          ? (selfEmployedManualIncomeEntries
                              ? manualIncomeGross
                              : parsedGross)
                          : (employeeCompensationType == 'hourly'
                              ? hourlyGross
                              : employeeFixedSalary);
                      final expensesBase =
                          userType == 'selfEmployed'
                              ? (selfEmployedManualExpenseEntries
                                  ? manualExpenseTotal
                                  : parsedExpenses)
                              : 0.0;
                      final fixedAdditionsTotal =
                          totalFixedAdditionAmount(fixedMonthlyItems);
                      final fixedExpensesTotal =
                          totalFixedExpenseAmount(fixedMonthlyItems);
                      final gross = grossBase + fixedAdditionsTotal;
                      final expenses = expensesBase + fixedExpensesTotal;
                      final deductionSnapshots = computeGrossDeductionSnapshots(
                        gross: gross,
                        deductions: grossDeductions,
                      );
                      final totalDeductions =
                          totalGrossDeductionAmount(deductionSnapshots);
                      final net = gross - totalDeductions - expenses;
                      final netColor = net >= 0 ? Colors.green : Colors.red;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (userType == 'selfEmployed') ...[
                            if (!selfEmployedManualIncomeEntries)
                              TextField(
                                controller: _grossController,
                                decoration: const InputDecoration(
                                  labelText: 'הכנסה ברוטו (₪)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            if (selfEmployedManualIncomeEntries)
                              _buildManualIncomeSection(
                                selectedKey: selectedKey,
                                entries: businessIncomeEntries,
                                total: manualIncomeGross,
                              ),
                            const SizedBox(height: 12),
                            if (!selfEmployedManualExpenseEntries)
                              TextField(
                                controller: _expensesController,
                                decoration: InputDecoration(
                                  labelText: 'סה״כ הוצאות $businessTabName (₪)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            if (selfEmployedManualExpenseEntries)
                              _buildManualExpenseSection(
                                selectedKey: selectedKey,
                                entries: businessExpenseEntries,
                                total: manualExpenseTotal,
                              ),
                            if (fixedExpensesTotal > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                'הוצאות קבועות (מהגדרות): ${fixedExpensesTotal.toStringAsFixed(0)} ₪',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (expensesBase > 0)
                                Text(
                                  'סה״כ הוצאות לחודש: ${expenses.toStringAsFixed(0)} ₪',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                            ],
                          ] else if (employeeCompensationType == 'fixed') ...[
                            Card(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withOpacity(0.35),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'שכר גלובלי חודשי: ${employeeFixedSalary.toStringAsFixed(0)} ₪',
                                    ),
                                    if (fixedAdditionsTotal > 0) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'תוספות קבועות: +${fixedAdditionsTotal.toStringAsFixed(0)} ₪',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'סה״כ ברוטו: ${gross.toStringAsFixed(0)} ₪',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'שכר שעתי: ${employeeHourlyRate.toStringAsFixed(2)} ₪ לשעה',
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'שעות שנרשמו במחזור: '
                                      '${hourlyEntries.fold<double>(0, (s, e) => s + e.hours).toStringAsFixed(2)}',
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'שכר מצטבר למחזור: ${hourlyGross.toStringAsFixed(0)} ₪',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    if (fixedAdditionsTotal > 0) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'תוספות קבועות: +${fixedAdditionsTotal.toStringAsFixed(0)} ₪',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'סה״כ ברוטו: ${gross.toStringAsFixed(0)} ₪',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: employeeHourlyRate <= 0
                                          ? null
                                          : () => _openAddHoursDialog(
                                                selectedKey,
                                                employeeHourlyRate,
                                              ),
                                      icon: const Icon(Icons.add),
                                      label: const Text('הוספת שעות'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            workHoursAsync.when(
                              data: (entries) {
                                if (entries.isEmpty) {
                                  return const Text('אין עדיין רשומות שעות למחזור זה.');
                                }
                                return Column(
                                  children: [
                                    for (final entry in entries)
                                      Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(horizontal: 12),
                                          title: Text(
                                            '${entry.hours.toStringAsFixed(2)} שעות',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${entry.date.day}.${entry.date.month}.${entry.date.year} • '
                                            '${(entry.hours * entry.hourlyRateSnapshot).toStringAsFixed(0)} ₪',
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline),
                                            onPressed: () => _deleteHoursEntry(
                                              selectedKey,
                                              entry.id,
                                              entries,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                              loading: () => const LinearProgressIndicator(minHeight: 2),
                              error: (e, _) => Text('שגיאה בטעינת שעות: $e'),
                            ),
                          ],
                          if (grossBase > 0 ||
                              fixedAdditionsTotal > 0 ||
                              expenses > 0) ...[
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'פירוט הכנסה',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 8),
                                    if (grossBase > 0)
                                      _buildBreakdownRow(
                                        context,
                                        label: userType == 'employee'
                                            ? 'שכר בסיס'
                                            : 'הכנסה ברוטו',
                                        amount: grossBase,
                                        emphasize: false,
                                      ),
                                    for (final item in activeFixedAdditions)
                                      _buildBreakdownRow(
                                        context,
                                        label: '${item.name} (קבוע)',
                                        amount: item.amount,
                                        emphasize: false,
                                        muted: true,
                                        isCredit: true,
                                      ),
                                    if (deductionSnapshots.isNotEmpty) ...[
                                      const Divider(height: 16),
                                      for (final line in deductionSnapshots)
                                        _buildBreakdownRow(
                                          context,
                                          label:
                                              '${line.name} (${line.percentage.toStringAsFixed(line.percentage.truncateToDouble() == line.percentage ? 0 : 1)}%)',
                                          amount: -line.amount,
                                          emphasize: false,
                                          muted: true,
                                        ),
                                    ],
                                    if (userType == 'selfEmployed' &&
                                        expensesBase > 0)
                                      _buildBreakdownRow(
                                        context,
                                        label: 'הוצאות משתנות',
                                        amount: -expensesBase,
                                        emphasize: false,
                                        muted: true,
                                      ),
                                    for (final item in activeFixedExpenses)
                                      _buildBreakdownRow(
                                        context,
                                        label: '${item.name} (קבוע)',
                                        amount: -item.amount,
                                        emphasize: false,
                                        muted: true,
                                      ),
                                    const Divider(height: 16),
                                    _buildBreakdownRow(
                                      context,
                                      label: 'נטו',
                                      amount: net,
                                      emphasize: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Card(
                            color: netColor.withOpacity(0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('רווח נטו לחודש:'),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${net.toStringAsFixed(0)} ₪',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: netColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (userType == 'selfEmployed') {
                                _saveMonth(
                                  selectedKey,
                                  forcedGross: selfEmployedManualIncomeEntries
                                      ? manualIncomeGross
                                      : null,
                                  forcedExpenses:
                                      selfEmployedManualExpenseEntries
                                          ? manualExpenseTotal
                                          : null,
                                );
                                return;
                              }
                              _saveMonth(
                                selectedKey,
                                forcedGross: grossBase,
                                forcedExpenses: 0,
                              );
                            },
                            child: Text(
                              userType == 'selfEmployed'
                                  ? 'שמור נתוני חודש'
                                  : 'שמור נתוני שכר למחזור',
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('שגיאה בטעינת חודש: $e')),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 280,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openChartFullscreen,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                isSelfEmployed
                                    ? 'השוואת חודשים – ברוטו, הוצאות, נטו'
                                    : 'השוואת חודשים – ברוטו, נטו',
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'לחץ על הגרף לתצוגה מלאה',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              const Expanded(child: _PensionBarChart(compact: true)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualIncomeSection({
    required PensionMonthKey selectedKey,
    required List<BusinessIncomeEntry> entries,
    required double total,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'הכנסות ברוטו (רשומות ידניות): ${total.toStringAsFixed(0)} ₪',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _openAddBusinessIncomeDialog(selectedKey),
              icon: const Icon(Icons.add),
              label: const Text('הוספת הכנסה'),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty) const Text('אין עדיין רשומות הכנסה למחזור זה.'),
            for (final entry in entries)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    '${entry.amount.toStringAsFixed(0)} ₪',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${entry.date.day}.${entry.date.month}.${entry.date.year}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteBusinessIncomeEntry(
                      selectedKey,
                      entry.id,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualExpenseSection({
    required PensionMonthKey selectedKey,
    required List<BusinessExpenseEntry> entries,
    required double total,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'הוצאות עסקיות (רשומות ידניות): ${total.toStringAsFixed(0)} ₪',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _openAddBusinessExpenseDialog(selectedKey),
              icon: const Icon(Icons.add),
              label: const Text('הוספת הוצאה עסקית'),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty) const Text('אין עדיין רשומות הוצאה למחזור זה.'),
            for (final entry in entries)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    '${entry.amount.toStringAsFixed(0)} ₪',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${entry.date.day}.${entry.date.month}.${entry.date.year}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteBusinessExpenseEntry(
                      selectedKey,
                      entry.id,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context, {
    required String label,
    required double amount,
    required bool emphasize,
    bool muted = false,
    bool isCredit = false,
  }) {
    final theme = Theme.of(context);
    final color = amount < 0
        ? theme.colorScheme.error
        : (emphasize
            ? theme.colorScheme.primary
            : (isCredit ? Colors.green.shade700 : null));
    final prefix = amount < 0 ? '−' : (isCredit ? '+' : '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: emphasize
                ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
                : (muted ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge),
          ),
          Text(
            '$prefix${amount.abs().toStringAsFixed(0)} ₪',
            style: (emphasize
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.bodyLarge)
                ?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  double _parseController(TextEditingController c) {
    final text = c.text.trim().replaceAll(',', '.');
    return double.tryParse(text) ?? 0;
  }

  Future<void> _saveMonth(
    PensionMonthKey key, {
    double? forcedGross,
    double? forcedExpenses,
  }) async {
    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;

    final grossBase = forcedGross ?? _parseController(_grossController);
    final expensesBase =
        forcedExpenses ?? _parseController(_expensesController);
    final profile = ref.read(currentUserProfileProvider).maybeWhen(
          data: (user) => user,
          orElse: () => null,
        );
    final fixedItems = profile?.fixedMonthlyItems ?? const [];
    final fixedAdditionsTotal = totalFixedAdditionAmount(fixedItems);
    final fixedExpensesTotal = totalFixedExpenseAmount(fixedItems);
    final gross = grossBase + fixedAdditionsTotal;
    final expenses = expensesBase + fixedExpensesTotal;
    final fixedSnapshots = snapshotsFromItems(fixedItems);
    final deductionSnapshots = computeGrossDeductionSnapshots(
      gross: gross,
      deductions: profile?.grossDeductions ?? const [],
    );
    final totalDeductions = totalGrossDeductionAmount(deductionSnapshots);
    final net = gross - totalDeductions - expenses;

    final repo = ref.read(pensionRepositoryProvider);
    final id = '${key.year}-${key.month.toString().padLeft(2, '0')}';
    final month = PensionMonth(
      id: id,
      userId: auth.uid,
      year: key.year,
      month: key.month,
      grossIncome: gross,
      totalGrossDeductions: totalDeductions,
      grossDeductionSnapshots: deductionSnapshots,
      totalFixedAdditions: fixedAdditionsTotal,
      totalFixedExpenses: fixedExpensesTotal,
      fixedMonthlySnapshots: fixedSnapshots,
      totalExpenses: expenses,
      netProfit: net,
    );
    await repo.upsertMonth(auth.uid, month);

    final savingsRepo = ref.read(savingsRepositoryProvider);
    await savingsRepo.syncFromPensionNet(
      userId: auth.uid,
      year: key.year,
      month: key.month,
      netProfit: net,
    );

    ref.invalidate(pensionMonthForProvider(key));
    ref.invalidate(currentPensionMonthProvider);
    ref.invalidate(recentPensionMonthsProvider(12));
    ref.invalidate(savingsMonthEntryProvider(key));
    ref.invalidate(recentSavingsMonthsProvider(48));
  }

  Future<void> _openAddHoursDialog(PensionMonthKey key, double hourlyRate) async {
    final hoursController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<(double, DateTime)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('הוספת שעות עבודה'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hoursController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'כמות שעות (למשל 2.5)',
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
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  setLocalState(() => selectedDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(
                  hoursController.text.trim().replaceAll(',', '.'),
                );
                if (parsed == null || parsed <= 0) return;
                Navigator.of(context).pop((parsed, selectedDate));
              },
              child: const Text('שמור'),
            ),
          ],
        ),
      ),
    );
    hoursController.dispose();
    if (!mounted || result == null) return;

    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;
    final repo = ref.read(pensionRepositoryProvider);
    await repo.addWorkHours(
      auth.uid,
      WorkHoursEntry(
        id: '',
        userId: auth.uid,
        date: result.$2,
        hours: result.$1,
        hourlyRateSnapshot: hourlyRate,
        createdAt: DateTime.now(),
      ),
    );
    ref.invalidate(workHoursForMonthProvider(key));
    final entries = await ref.read(workHoursForMonthProvider(key).future);
    await _syncHourlyMonthFromEntries(key, entries);
  }

  Future<void> _openAddBusinessIncomeDialog(PensionMonthKey key) async {
    final result = await _openAmountAndDateDialog(title: 'הוספת הכנסה');
    if (!mounted || result == null) return;
    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;
    await ref.read(pensionRepositoryProvider).addBusinessIncome(
          auth.uid,
          BusinessIncomeEntry(
            id: '',
            userId: auth.uid,
            date: result.$2,
            amount: result.$1,
            createdAt: DateTime.now(),
          ),
        );
    ref.invalidate(businessIncomeEntriesForMonthProvider(key));
    await _syncSelfEmployedMonthFromManualEntries(key);
  }

  Future<void> _openAddBusinessExpenseDialog(PensionMonthKey key) async {
    final result = await _openAmountAndDateDialog(title: 'הוספת הוצאה עסקית');
    if (!mounted || result == null) return;
    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;
    await ref.read(pensionRepositoryProvider).addBusinessExpense(
          auth.uid,
          BusinessExpenseEntry(
            id: '',
            userId: auth.uid,
            date: result.$2,
            amount: result.$1,
            createdAt: DateTime.now(),
          ),
        );
    ref.invalidate(businessExpenseEntriesForMonthProvider(key));
    await _syncSelfEmployedMonthFromManualEntries(key);
  }

  Future<void> _deleteBusinessIncomeEntry(
    PensionMonthKey key,
    String entryId,
  ) async {
    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;
    await ref.read(pensionRepositoryProvider).deleteBusinessIncome(
          auth.uid,
          entryId,
        );
    ref.invalidate(businessIncomeEntriesForMonthProvider(key));
    await _syncSelfEmployedMonthFromManualEntries(key);
  }

  Future<void> _deleteBusinessExpenseEntry(
    PensionMonthKey key,
    String entryId,
  ) async {
    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;
    await ref.read(pensionRepositoryProvider).deleteBusinessExpense(
          auth.uid,
          entryId,
        );
    ref.invalidate(businessExpenseEntriesForMonthProvider(key));
    await _syncSelfEmployedMonthFromManualEntries(key);
  }

  Future<(double, DateTime)?> _openAmountAndDateDialog({
    required String title,
  }) async {
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final result = await showDialog<(double, DateTime)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'סכום (₪)',
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
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  setLocalState(() => selectedDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(
                  amountController.text.trim().replaceAll(',', '.'),
                );
                if (parsed == null || parsed <= 0) return;
                Navigator.of(context).pop((parsed, selectedDate));
              },
              child: const Text('שמור'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    return result;
  }

  Future<void> _deleteHoursEntry(
    PensionMonthKey key,
    String entryId,
    List<WorkHoursEntry> existing,
  ) async {
    final auth = ref.read(currentAuthUserProvider);
    if (auth == null) return;
    await ref.read(pensionRepositoryProvider).deleteWorkHours(auth.uid, entryId);
    ref.invalidate(workHoursForMonthProvider(key));
    final refreshed = existing.where((e) => e.id != entryId).toList();
    await _syncHourlyMonthFromEntries(key, refreshed);
  }

  Future<void> _syncHourlyMonthFromEntries(
    PensionMonthKey key,
    List<WorkHoursEntry> entries,
  ) async {
    final gross = entries.fold<double>(
      0,
      (sum, e) => sum + (e.hours * e.hourlyRateSnapshot),
    );
    await _saveMonth(key, forcedGross: gross, forcedExpenses: 0);
  }

  Future<void> _syncSelfEmployedMonthFromManualEntries(PensionMonthKey key) async {
    final profile = await ref.read(currentUserProfileProvider.future);
    if (profile == null || profile.userType != 'selfEmployed') return;
    final manualIncome = profile.selfEmployedManualIncomeEntries;
    final manualExpense = profile.selfEmployedManualExpenseEntries;
    if (!manualIncome && !manualExpense) return;

    final incomeEntries = manualIncome
        ? await ref.read(businessIncomeEntriesForMonthProvider(key).future)
        : const <BusinessIncomeEntry>[];
    final expenseEntries = manualExpense
        ? await ref.read(businessExpenseEntriesForMonthProvider(key).future)
        : const <BusinessExpenseEntry>[];
    final forcedGross = manualIncome
        ? incomeEntries.fold<double>(0, (sum, e) => sum + e.amount)
        : null;
    final forcedExpenses = manualExpense
        ? expenseEntries.fold<double>(0, (sum, e) => sum + e.amount)
        : null;
    await _saveMonth(
      key,
      forcedGross: forcedGross,
      forcedExpenses: forcedExpenses,
    );
  }
}

class _PensionBarChart extends ConsumerWidget {
  const _PensionBarChart({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthsAsync = ref.watch(recentPensionMonthsProvider(12));
    final userType = ref.watch(currentUserProfileProvider).maybeWhen(
          data: (profile) => profile?.userType ?? 'selfEmployed',
          orElse: () => 'selfEmployed',
        );
    final includeExpenses = userType == 'selfEmployed';

    return monthsAsync.when(
      data: (months) {
        if (months.isEmpty) {
          return const Center(
            child: Text('אין עדיין נתונים להשוואת חודשים. הזן נתונים לחודשים שונים.'),
          );
        }
        final maxValue = months
                .map((m) => includeExpenses
                    ? [m.grossIncome, m.totalExpenses, m.netProfit.abs()]
                        .reduce((a, b) => a > b ? a : b)
                    : [m.grossIncome, m.netProfit.abs()]
                        .reduce((a, b) => a > b ? a : b))
                .fold<double>(0, (max, v) => v > max ? v : max) *
            1.2;

        return BarChart(
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
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= months.length) {
                      return const SizedBox.shrink();
                    }
                    final m = months[index];
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${m.month}/${m.year % 100}',
                        style: TextStyle(fontSize: compact ? 10 : 12),
                      ),
                    );
                  },
                ),
              ),
            ),
            maxY: maxValue == 0 ? 100 : maxValue,
            barGroups: [
              for (var i = 0; i < months.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 2,
                  barRods: [
                    BarChartRodData(
                      toY: months[i].grossIncome,
                      width: compact ? 6 : 10,
                      color: Colors.blue,
                    ),
                    if (includeExpenses)
                      BarChartRodData(
                        toY: months[i].totalExpenses,
                        width: compact ? 6 : 10,
                        color: Colors.orange,
                      ),
                    BarChartRodData(
                      toY: months[i].netProfit >= 0
                          ? months[i].netProfit
                          : -months[i].netProfit,
                      width: compact ? 6 : 10,
                      color:
                          months[i].netProfit >= 0 ? Colors.green : Colors.red,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('שגיאה בטעינת חודשים: $e')),
    );
  }
}
