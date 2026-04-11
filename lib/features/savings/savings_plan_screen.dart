import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/date_helpers.dart';
import '../../core/models/savings_models.dart';
import '../../core/repositories/providers.dart';

class SavingsPlanScreen extends ConsumerStatefulWidget {
  const SavingsPlanScreen({super.key});

  @override
  ConsumerState<SavingsPlanScreen> createState() => _SavingsPlanScreenState();
}

class _SavingsPlanScreenState extends ConsumerState<SavingsPlanScreen> {
  double _percentDraft = 0;
  bool _percentLoaded = false;

  int? _selectedYear;
  int? _selectedMonth;

  static const _monthNames = [
    '', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
    'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    Future<void>.delayed(Duration.zero, _loadPercentFromServer);
  }

  Future<void> _loadPercentFromServer() async {
    final s = await ref.read(savingsSettingsProvider.future);
    if (!mounted) return;
    setState(() {
      _percentDraft = s?.savingsPercent ?? 0;
      _percentLoaded = true;
    });
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

  Future<void> _savePercent() async {
    final auth = ref.read(firebaseAuthProvider).currentUser;
    if (auth == null) return;
    final repo = ref.read(savingsRepositoryProvider);
    final clamped = _percentDraft.clamp(0.0, 1.0);
    await repo.upsertSettings(
      auth.uid,
      SavingsSettings(
        savingsPercent: clamped,
        updatedAt: DateTime.now(),
      ),
    );
    ref.invalidate(savingsSettingsProvider);

    final pension =
        await ref.read(pensionMonthForProvider(_selectedKey).future);
    if (pension != null) {
      await repo.syncFromPensionNet(
        userId: auth.uid,
        year: _selectedKey.year,
        month: _selectedKey.month,
        netProfit: pension.netProfit,
      );
      ref.invalidate(savingsMonthEntryProvider(_selectedKey));
      ref.invalidate(recentSavingsMonthsProvider(48));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('אחוז החיסכון נשמר')),
      );
    }
  }

  Future<void> _onDepositedChanged(bool value) async {
    final auth = ref.read(firebaseAuthProvider).currentUser;
    if (auth == null) return;

    final entry =
        await ref.read(savingsMonthEntryProvider(_selectedKey).future);
    if (entry == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'אין עדיין רשומת חיסכון לחודש זה. שמור קודם את נתוני החודש בפנסיון.',
            ),
          ),
        );
      }
      return;
    }

    final repo = ref.read(savingsRepositoryProvider);
    await repo.setDeposited(
      userId: auth.uid,
      year: _selectedKey.year,
      month: _selectedKey.month,
      deposited: value,
      depositedAt: value ? DateTime.now() : null,
    );
    ref.invalidate(savingsMonthEntryProvider(_selectedKey));
    ref.invalidate(recentSavingsMonthsProvider(48));
  }

  Future<void> _pickDepositedDate() async {
    final entry =
        await ref.read(savingsMonthEntryProvider(_selectedKey).future);
    if (entry == null || !entry.deposited) return;
    if (!mounted) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: entry.depositedAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;

    final auth = ref.read(firebaseAuthProvider).currentUser;
    if (auth == null) return;
    final repo = ref.read(savingsRepositoryProvider);
    await repo.setDeposited(
      userId: auth.uid,
      year: _selectedKey.year,
      month: _selectedKey.month,
      deposited: true,
      depositedAt: picked,
    );
    ref.invalidate(savingsMonthEntryProvider(_selectedKey));
    ref.invalidate(recentSavingsMonthsProvider(48));
  }

  @override
  Widget build(BuildContext context) {
    final key = _selectedKey;
    final pensionAsync = ref.watch(pensionMonthForProvider(key));
    final savingsEntryAsync = ref.watch(savingsMonthEntryProvider(key));
    final settingsAsync = ref.watch(savingsSettingsProvider);
    final recentAsync = ref.watch(recentSavingsMonthsProvider(48));

    final net = pensionAsync.maybeWhen(
      data: (p) => p?.netProfit,
      orElse: () => null,
    );
    final settingsPercent = settingsAsync.maybeWhen(
      data: (s) => s?.savingsPercent ?? 0,
      orElse: () => 0.0,
    );
    final previewTarget =
        (net != null && net > 0) ? net * settingsPercent : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('תוכנית חיסכון'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'אחוז חיסכון מהכנסה נטו (פנסיון)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (!_percentLoaded)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _percentDraft,
                          min: 0,
                          max: 0.5,
                          divisions: 50,
                          label: '${(_percentDraft * 100).round()}%',
                          onChanged: (v) =>
                              setState(() => _percentDraft = v),
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '${(_percentDraft * 100).round()}%',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ElevatedButton(
                  onPressed: _percentLoaded ? _savePercent : null,
                  child: const Text('שמור אחוז'),
                ),
                const SizedBox(height: 8),
                Text(
                  'שינוי האחוז חל על חודשים שיסונכרנו מפנסיון מעתה; לכל חודש נשמר אחוז (snapshot) בנפרד.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                pensionAsync.when(
                  data: (pension) {
                    if (pension == null) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'טרם נשמרו נתוני פנסיון לחודש זה. '
                            'לאחר שמירה בפנסיון יחושב יעד החיסכון אוטומטית.',
                          ),
                        ),
                      );
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'הכנסה נטו מפנסיון (אותו חודש): '
                              '${pension.netProfit.toStringAsFixed(0)} ₪',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            savingsEntryAsync.when(
                              data: (entry) {
                                if (entry != null) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'יעד הפקדה לחודש זה: '
                                        '${entry.targetAmount.toStringAsFixed(0)} ₪',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'חושב לפי '
                                        '${(entry.percentSnapshot * 100).toStringAsFixed(0)}% '
                                        '× נטו ${entry.pensionNetSnapshot.toStringAsFixed(0)} ₪',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const SizedBox(height: 16),
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('בוצעה הפקדה לחיסכון'),
                                        subtitle: const Text(
                                          'סמן כשהכסף יצא בפועל (גם אם התאריך שונה מהחודש)',
                                        ),
                                        value: entry.deposited,
                                        onChanged: _onDepositedChanged,
                                      ),
                                      if (entry.deposited) ...[
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(
                                              Icons.event_available_outlined),
                                          title: const Text(
                                            'תאריך הפקדה בפועל',
                                          ),
                                          subtitle: Text(
                                            entry.depositedAt != null
                                                ? '${entry.depositedAt!.day}.'
                                                    '${entry.depositedAt!.month}.'
                                                    '${entry.depositedAt!.year}'
                                                : 'לא הוגדר',
                                          ),
                                          trailing: const Icon(
                                              Icons.edit_calendar_outlined),
                                          onTap: _pickDepositedDate,
                                        ),
                                      ],
                                    ],
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'תצוגה מקדימה (יעד יישמר אחרי «שמור נתוני חודש» בפנסיון): '
                                      '${previewTarget.toStringAsFixed(0)} ₪',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'לפי אחוז נוכחי '
                                      '${(settingsPercent * 100).round()}% × נטו',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                );
                              },
                              loading: () =>
                                  const LinearProgressIndicator(minHeight: 2),
                              error: (e, _) => Text('שגיאה: $e'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('שגיאה בפנסיון: $e'),
                ),
                const SizedBox(height: 24),
                Text(
                  'היסטוריה והשוואה בין חודשים',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'לכל חודש: יעד הפקדה לפי נטו הפנסיון, וסימון אם בוצעה הפקדה בפועל.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 12),
                recentAsync.when(
                  data: (months) {
                    if (months.isEmpty) {
                      return const Text(
                        'אין עדיין רשומות חיסכון. שמור נתונים בפנסיון כדי ליצור יעדים.',
                      );
                    }
                    final chartMonths = months.length > 12
                        ? months.sublist(0, 12).reversed.toList()
                        : months.reversed.toList();
                    var maxTarget = 0.0;
                    for (final e in chartMonths) {
                      if (e.targetAmount > maxTarget) maxTarget = e.targetAmount;
                    }
                    final chartMaxY = maxTarget <= 0 ? 100.0 : maxTarget * 1.15;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'יעד הפקדה לפי חודש (₪)',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
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
                                    reservedSize: 28,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i < 0 || i >= chartMonths.length) {
                                        return const SizedBox.shrink();
                                      }
                                      final cm = chartMonths[i];
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${cm.month}/${cm.year % 100}',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              maxY: chartMaxY,
                              barGroups: [
                                for (var i = 0; i < chartMonths.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: chartMonths[i].targetAmount,
                                        width: 14,
                                        borderRadius: BorderRadius.circular(4),
                                        color: chartMonths[i].deposited
                                            ? Colors.teal
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _LegendDot(
                              color: Theme.of(context).colorScheme.primary,
                              label: 'יעד (טרם סומן ביצוע)',
                            ),
                            const SizedBox(width: 16),
                            const _LegendDot(
                              color: Colors.teal,
                              label: 'יעד (בוצע)',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...months.map(
                          (m) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                '${_monthNames[m.month]} ${m.year}',
                              ),
                              subtitle: Text(
                                'יעד הפקדה: ${m.targetAmount.toStringAsFixed(0)} ₪'
                                ' • נטו פנסיון: ${m.pensionNetSnapshot.toStringAsFixed(0)} ₪'
                                ' • ${m.deposited ? "בוצעה הפקדה" : "טרם סומן ביצוע"}',
                              ),
                              trailing: m.deposited
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : Icon(
                                      Icons.pending_outlined,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                    ),
                              onTap: () {
                                setState(() {
                                  _selectedYear = m.year;
                                  _selectedMonth = m.month;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('שגיאה בטעינת היסטוריה: $e'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
