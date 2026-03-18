import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/pension_models.dart';
import '../../core/models/date_helpers.dart';
import '../../core/repositories/providers.dart';

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
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
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
    final now = DateTime.now();
    setState(() {
      _selectedYear = now.year;
      _selectedMonth = now.month;
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

  static const _monthNames = [
    '', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
    'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר',
  ];

  @override
  Widget build(BuildContext context) {
    final selectedKey = _selectedKey;
    final monthAsync = ref.watch(pensionMonthForProvider(selectedKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('פנסיון'),
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
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _goToPrevMonth,
                      tooltip: 'חודש קודם',
                    ),
                    Column(
                      children: [
                        Text(
                          '${_monthNames[_selectedMonth!]} $_selectedYear',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton.icon(
                          onPressed: _goToCurrentMonth,
                          icon: const Icon(Icons.today, size: 18),
                          label: const Text('חודש נוכחי'),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _goToNextMonth,
                      tooltip: 'חודש הבא',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            monthAsync.when(
              data: (month) {
                if (_lastAppliedKey != selectedKey) {
                  _lastAppliedKey = selectedKey;
                  if (month != null) {
                    _grossController.text =
                        month.grossIncome.toStringAsFixed(0);
                    _expensesController.text =
                        month.totalExpenses.toStringAsFixed(0);
                  } else {
                    _grossController.clear();
                    _expensesController.clear();
                  }
                }
                final net = _calculateNet();
                final netColor = net >= 0 ? Colors.green : Colors.red;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _grossController,
                      decoration: const InputDecoration(
                        labelText: 'הכנסה ברוטו (₪)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _expensesController,
                      decoration: const InputDecoration(
                        labelText: 'סה״כ הוצאות פנסיון (₪)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
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
                      onPressed: () => _saveMonth(selectedKey),
                      child: const Text('שמור נתוני חודש'),
                    ),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('שגיאה בטעינת חודש: $e')),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      Text('השוואת חודשים – ברוטו, הוצאות, נטו'),
                      SizedBox(height: 8),
                      Expanded(child: _PensionBarChart()),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _parseController(TextEditingController c) {
    final text = c.text.trim().replaceAll(',', '.');
    return double.tryParse(text) ?? 0;
  }

  double _calculateNet() {
    final gross = _parseController(_grossController);
    final expenses = _parseController(_expensesController);
    return gross - expenses;
  }

  Future<void> _saveMonth(PensionMonthKey key) async {
    final auth = ref.read(firebaseAuthProvider).currentUser;
    if (auth == null) return;

    final gross = _parseController(_grossController);
    final expenses = _parseController(_expensesController);
    final net = gross - expenses;

    final repo = ref.read(pensionRepositoryProvider);
    final id = '${key.year}-${key.month.toString().padLeft(2, '0')}';
    final month = PensionMonth(
      id: id,
      year: key.year,
      month: key.month,
      grossIncome: gross,
      totalExpenses: expenses,
      netProfit: net,
    );
    await repo.upsertMonth(auth.uid, month);
    ref.invalidate(pensionMonthForProvider(key));
    ref.invalidate(currentPensionMonthProvider);
    ref.invalidate(recentPensionMonthsProvider(12));
  }
}

class _PensionBarChart extends ConsumerWidget {
  const _PensionBarChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthsAsync = ref.watch(recentPensionMonthsProvider(12));

    return monthsAsync.when(
      data: (months) {
        if (months.isEmpty) {
          return const Center(
            child: Text('אין עדיין נתונים להשוואת חודשים. הזן נתונים לחודשים שונים.'),
          );
        }
        final maxValue = months
                .map((m) =>
                    [m.grossIncome, m.totalExpenses, m.netProfit.abs()]
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
                        style: const TextStyle(fontSize: 10),
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
                      width: 6,
                      color: Colors.blue,
                    ),
                    BarChartRodData(
                      toY: months[i].totalExpenses,
                      width: 6,
                      color: Colors.orange,
                    ),
                    BarChartRodData(
                      toY: months[i].netProfit >= 0
                          ? months[i].netProfit
                          : -months[i].netProfit,
                      width: 6,
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
