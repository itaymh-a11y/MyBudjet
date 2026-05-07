import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/date_helpers.dart';
import '../../core/models/user_model.dart';
import '../../core/repositories/providers.dart';

class SavingsPlanScreen extends ConsumerStatefulWidget {
  const SavingsPlanScreen({super.key});

  @override
  ConsumerState<SavingsPlanScreen> createState() => _SavingsPlanScreenState();
}

class _SavingsPlanScreenState extends ConsumerState<SavingsPlanScreen> {
  double _percentDraft = 0;
  bool _percentLoaded = false;
  String? _lastSyncedSignature;
  bool _syncInProgress = false;

  int? _selectedYear;
  int? _selectedMonth;

  static const _monthNames = [
    '', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
    'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר',
  ];

  @override
  void initState() {
    super.initState();
    final key = ref.read(currentPensionMonthKeyProvider);
    _selectedYear = key.year;
    _selectedMonth = key.month;
    Future<void>.delayed(Duration.zero, _loadPercentFromServer);
  }

  // Supports legacy fraction format (0..1) and percent format (0..100).
  double _normalizePercentForSlider(double raw) {
    final normalized = raw <= 1.0 ? raw * 100.0 : raw;
    return normalized.clamp(0.0, 100.0);
  }

  bool _isSamePercent(double a, double b) => (a - b).abs() < 0.001;

  Future<void> _loadPercentFromServer() async {
    final userProfile = await ref.read(currentUserProfileProvider.future);
    if (!mounted) return;
    setState(() {
      _percentDraft =
          _normalizePercentForSlider(userProfile?.savingsPercentage ?? 0);
      _percentLoaded = true;
    });
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

  Future<void> _savePercent() async {
    final auth = ref.read(firebaseAuthProvider).currentUser;
    if (auth == null) return;
    final userRepo = ref.read(userRepositoryProvider);
    final clamped = _percentDraft.clamp(0.0, 100.0);
    final currentProfile = await userRepo.getUser(auth.uid);
    if (currentProfile == null) return;
    await userRepo.updateUserSettings(
      userId: auth.uid,
      userType: currentProfile.userType,
      savingsPercentage: clamped,
      deductPersonalExpenses: currentProfile.deductPersonalExpenses,
      businessTabName: currentProfile.businessTabName,
      businessIconName: currentProfile.businessIconName,
      personalCycleStartDay: currentProfile.personalCycleStartDay,
      businessCycleStartDay: currentProfile.businessCycleStartDay,
      employeeCompensationType: currentProfile.employeeCompensationType,
      employeeFixedMonthlySalary: currentProfile.employeeFixedMonthlySalary,
      employeeHourlyRate: currentProfile.employeeHourlyRate,
    );
    ref.invalidate(currentUserProfileProvider);

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
      final profile = await ref.read(currentUserProfileProvider.future);
      final name = profile?.businessTabName.trim();
      final businessTabName =
          (name == null || name.isEmpty) ? 'הכנסות' : name;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'אין עדיין רשומת חיסכון לחודש זה. שמור קודם את נתוני החודש ב$businessTabName.',
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

  Future<void> _syncSuggestedTargetIfNeeded({
    required PensionMonthKey key,
    required double suggestedDeposit,
    required double effectivePercent,
    required double baseAfterDeduction,
  }) async {
    final auth = ref.read(firebaseAuthProvider).currentUser;
    if (auth == null) return;
    final signature =
        '${key.year}-${key.month}|${suggestedDeposit.toStringAsFixed(2)}|'
        '${effectivePercent.toStringAsFixed(2)}|${baseAfterDeduction.toStringAsFixed(2)}';
    if (_lastSyncedSignature == signature || _syncInProgress) return;

    _syncInProgress = true;
    try {
      await ref.read(savingsRepositoryProvider).syncSuggestedTargetForMonth(
            userId: auth.uid,
            year: key.year,
            month: key.month,
            targetAmount: suggestedDeposit,
            // keep snapshot as ratio for backward compatibility
            percentSnapshot: effectivePercent / 100.0,
            baseAmountSnapshot: baseAfterDeduction,
          );
      _lastSyncedSignature = signature;
      ref.invalidate(savingsMonthEntryProvider(key));
      ref.invalidate(recentSavingsMonthsProvider(48));
    } finally {
      _syncInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _selectedKey;
    final pensionAsync = ref.watch(pensionMonthForProvider(key));
    final savingsEntryAsync = ref.watch(savingsMonthEntryProvider(key));
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final personalExpensesAsync = ref.watch(personalExpensesForMonthProvider(key));
    final recentAsync = ref.watch(recentSavingsMonthsProvider(48));

    final baseIncome = pensionAsync.maybeWhen(
      data: (p) {
        if (p == null) return null;
        return userProfileAsync.maybeWhen(
          data: (u) => u?.userType == 'employee' ? p.grossIncome : p.netProfit,
          orElse: () => p.netProfit,
        );
      },
      orElse: () => null,
    );
    final userSavingsPercent = userProfileAsync.maybeWhen(
      data: (u) => u?.savingsPercentage ?? 0.0,
      orElse: () => 0.0,
    );
    final normalizedUserPercent =
        _normalizePercentForSlider(userSavingsPercent);

    ref.listen<AsyncValue<UserModel?>>(currentUserProfileProvider, (_, next) {
      next.whenData((profile) {
        if (!mounted || profile == null) return;
        final incoming =
            _normalizePercentForSlider(profile.savingsPercentage);
        if (!_isSamePercent(_percentDraft, incoming)) {
          setState(() {
            _percentDraft = incoming;
            _percentLoaded = true;
          });
        }
      });
    });
    final effectivePercent = _percentLoaded ? _percentDraft : normalizedUserPercent;
    final savingsRatio = effectivePercent / 100.0;
    final deductPersonal = userProfileAsync.maybeWhen(
      data: (u) => u?.deductPersonalExpenses ?? false,
      orElse: () => false,
    );
    final businessTabName = userProfileAsync.maybeWhen(
      data: (u) {
        final value = u?.businessTabName.trim();
        if (value == null || value.isEmpty) return 'הכנסות';
        return value;
      },
      orElse: () => 'הכנסות',
    );
    final personalTotal = personalExpensesAsync.maybeWhen(
      data: (list) => list.fold<double>(0, (sum, e) => sum + e.amount),
      orElse: () => 0.0,
    );
    final adjustedBase = () {
      final rawBase = baseIncome ?? 0.0;
      if (!deductPersonal) return rawBase;
      return rawBase - personalTotal;
    }();
    final adjustedBaseForCalc = adjustedBase < 0 ? 0.0 : adjustedBase;
    final suggestedDeposit =
        adjustedBaseForCalc > 0 ? adjustedBaseForCalc * savingsRatio : 0.0;

    final hasCalculationData = pensionAsync.maybeWhen(
      data: (p) => p != null,
      orElse: () => false,
    );
    if (hasCalculationData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncSuggestedTargetIfNeeded(
          key: key,
          suggestedDeposit: suggestedDeposit,
          effectivePercent: effectivePercent,
          baseAfterDeduction: adjustedBaseForCalc,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('תוכנית חיסכון'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'אחוז חיסכון מההגדרות הכלליות',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
                              max: 100,
                              divisions: 100,
                              label: '${_percentDraft.round()}%',
                              onChanged: (v) =>
                                  setState(() => _percentDraft = v),
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              '${_percentDraft.round()}%',
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
                      'האחוז נשמר גם במסך ההגדרות ומשמש לחישוב יעד חיסכון מוצע.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
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
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'טרם נשמרו נתוני $businessTabName לחודש זה. '
                            'לאחר שמירה ב$businessTabName יחושב יעד החיסכון אוטומטית.',
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
                              '${userProfileAsync.maybeWhen(
                                            data: (u) => u?.userType == 'employee',
                                            orElse: () => false,
                                          )
                                      ? 'הכנסה משכר (אותו חודש): '
                                      : 'הכנסה נטו עסקית (אותו חודש): '}${baseIncome?.toStringAsFixed(0) ?? '0'} ₪',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (deductPersonal) ...[
                              const SizedBox(height: 4),
                              Text(
                                'קיזוז הוצאות אישיות: ${personalTotal.toStringAsFixed(0)} ₪',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'יעד חיסכון מוצע: ${suggestedDeposit.toStringAsFixed(0)} ₪',
                              style: Theme.of(context).textTheme.titleSmall,
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
                                        '(${baseIncome?.toStringAsFixed(0) ?? '0'}'
                                        '${deductPersonal ? ' - ${personalTotal.toStringAsFixed(0)}' : ''})'
                                        ' × ${effectivePercent.toStringAsFixed(0)}%',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'בסיס לחישוב אחרי קיזוז: ${adjustedBaseForCalc.toStringAsFixed(0)} ₪',
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
                                      'תצוגה מקדימה (יעד יישמר אחרי «שמור נתוני חודש» ב$businessTabName): '
                                      '${suggestedDeposit.toStringAsFixed(0)} ₪',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'לפי אחוז נוכחי '
                                      '${effectivePercent.round()}% × (${baseIncome?.toStringAsFixed(0) ?? '0'}'
                                      '${deductPersonal ? ' - ${personalTotal.toStringAsFixed(0)}' : ''})',
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
                  error: (e, _) => Text('שגיאה ב$businessTabName: $e'),
                ),
                const SizedBox(height: 24),
                Text(
                  'היסטוריה והשוואה בין חודשים',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'לכל חודש: יעד הפקדה לפי נטו $businessTabName, וסימון אם בוצעה הפקדה בפועל.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 12),
                recentAsync.when(
                  data: (months) {
                    if (months.isEmpty) {
                      return Text(
                        'אין עדיין רשומות חיסכון. שמור נתונים ב$businessTabName כדי ליצור יעדים.',
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
                                ' • נטו $businessTabName: ${m.pensionNetSnapshot.toStringAsFixed(0)} ₪'
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
