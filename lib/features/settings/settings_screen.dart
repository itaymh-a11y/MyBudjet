import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/business_professions.dart';
import '../../core/models/fixed_monthly_models.dart';
import '../../core/models/gross_deduction_models.dart';
import '../../core/models/student_models.dart';
import '../../core/repositories/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _savingsController = TextEditingController();
  final _businessTabNameController = TextEditingController();
  final _employeeFixedSalaryController = TextEditingController();
  final _employeeHourlyRateController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String _selectedUserType = 'selfEmployed';
  bool _deductPersonalExpenses = false;
  String _businessIconName = BusinessProfessionCatalog.defaultIconName;
  int _personalCycleStartDay = 10;
  int _businessCycleStartDay = 1;
  String _employeeCompensationType = 'fixed';
  bool _selfEmployedManualIncomeEntries = false;
  bool _selfEmployedManualExpenseEntries = false;
  List<FixedGrossDeduction> _grossDeductions = const [];
  List<FixedMonthlyItem> _fixedMonthlyItems = const [];
  List<IncomeSource> _incomeSources = const [];

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  @override
  void dispose() {
    _savingsController.dispose();
    _businessTabNameController.dispose();
    _employeeFixedSalaryController.dispose();
    _employeeHourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _loadUserSettings() async {
    final authUser = ref.read(firebaseAuthProvider).currentUser;
    if (authUser == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final userRepo = ref.read(userRepositoryProvider);
    final user = await userRepo.getUser(authUser.uid);

    if (!mounted) return;
    setState(() {
      _selectedUserType = user?.userType ?? 'selfEmployed';
      _savingsController.text =
          (user?.savingsPercentage ?? 0.0).toStringAsFixed(2);
      _deductPersonalExpenses = user?.deductPersonalExpenses ?? false;
      _businessTabNameController.text = user?.businessTabName ?? 'הכנסות';
      _businessIconName =
          user?.businessIconName ?? BusinessProfessionCatalog.defaultIconName;
      _personalCycleStartDay = user?.personalCycleStartDay ?? 10;
      _businessCycleStartDay = user?.businessCycleStartDay ?? 1;
      _employeeCompensationType = user?.employeeCompensationType ?? 'fixed';
      _employeeFixedSalaryController.text =
          (user?.employeeFixedMonthlySalary ?? 0.0).toStringAsFixed(0);
      _employeeHourlyRateController.text =
          (user?.employeeHourlyRate ?? 0.0).toStringAsFixed(2);
      _selfEmployedManualIncomeEntries =
          user?.selfEmployedManualIncomeEntries ?? false;
      _selfEmployedManualExpenseEntries =
          user?.selfEmployedManualExpenseEntries ?? false;
      _grossDeductions = List<FixedGrossDeduction>.from(
        user?.grossDeductions ?? const [],
      );
      _fixedMonthlyItems = List<FixedMonthlyItem>.from(
        user?.fixedMonthlyItems ?? const [],
      );
      _incomeSources = List<IncomeSource>.from(
        user?.incomeSources ?? const [],
      );
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final authUser = ref.read(firebaseAuthProvider).currentUser;
    if (authUser == null) return;

    final raw = _savingsController.text.trim();
    final parsed = double.tryParse(raw);
    final percentage = parsed ?? 0.0;
    final businessTabName = _businessTabNameController.text.trim().isEmpty
        ? 'הכנסות'
        : _businessTabNameController.text.trim();
    final employeeFixedSalary = double.tryParse(
          _employeeFixedSalaryController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
    final employeeHourlyRate = double.tryParse(
          _employeeHourlyRateController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;

    setState(() => _isSaving = true);
    try {
      await ref.read(userRepositoryProvider).updateUserSettings(
            userId: authUser.uid,
            userType: _selectedUserType,
            savingsPercentage: percentage,
            deductPersonalExpenses: _deductPersonalExpenses,
            businessTabName: businessTabName,
            businessIconName: _businessIconName,
            personalCycleStartDay: _personalCycleStartDay,
            businessCycleStartDay: _businessCycleStartDay,
            employeeCompensationType: _employeeCompensationType,
            employeeFixedMonthlySalary: employeeFixedSalary,
            employeeHourlyRate: employeeHourlyRate,
            selfEmployedManualIncomeEntries: _selfEmployedManualIncomeEntries,
            selfEmployedManualExpenseEntries: _selfEmployedManualExpenseEntries,
            grossDeductions: _grossDeductions,
            fixedMonthlyItems: _fixedMonthlyItems,
            incomeSources: _incomeSources,
          );
      ref.invalidate(currentUserProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ההגדרות עודכנו בהצלחה')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('אירעה שגיאה בעדכון ההגדרות')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('הגדרות חשבון'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    Card(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.35),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'פרופיל והגדרות עבודה',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      value: 'selfEmployed',
                      groupValue: _selectedUserType,
                      title: const Text('עצמאי'),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedUserType = value);
                      },
                    ),
                    RadioListTile<String>(
                      value: 'employee',
                      groupValue: _selectedUserType,
                      title: const Text('שכיר'),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedUserType = value);
                      },
                    ),
                    RadioListTile<String>(
                      value: 'student',
                      groupValue: _selectedUserType,
                      title: const Text('סטודנט/ית'),
                      subtitle: const Text('מספר עבודות מזדמנות + מלגות'),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedUserType = value);
                      },
                    ),
                    if (_selectedUserType == 'student') ...[
                      const SizedBox(height: 8),
                      Card(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.35),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'מקורות הכנסה מעבודה',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'הגדירי כל עבודה עם תעריף שעתי או שכר קבוע חודשי',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              if (_incomeSources.isEmpty)
                                Text(
                                  'אין מקורות הכנסה מוגדרים',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              for (final source in _incomeSources)
                                Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Icon(
                                        incomeSourceIconFromName(source.iconName),
                                      ),
                                    ),
                                    title: Text(source.name),
                                    subtitle: Text(
                                      source.isHourly
                                          ? '${source.hourlyRate.toStringAsFixed(0)} ₪ לשעה'
                                          : '${source.fixedMonthlyAmount.toStringAsFixed(0)} ₪ קבוע לחודש',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _openIncomeSourceDialog(
                                            existing: source,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          onPressed: () {
                                            setState(() {
                                              _incomeSources = _incomeSources
                                                  .where(
                                                    (item) =>
                                                        item.id != source.id,
                                                  )
                                                  .toList();
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => _openIncomeSourceDialog(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('הוספת מקור הכנסה'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_selectedUserType == 'selfEmployed') ...[
                      const SizedBox(height: 8),
                      Card(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.35),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('הזנת הכנסות ידנית (עם +)'),
                              subtitle: const Text(
                                'כאשר פעיל, תתווסף אפשרות להוסיף הכנסות לפי תאריך וסכום',
                              ),
                              value: _selfEmployedManualIncomeEntries,
                              onChanged: (value) => setState(
                                () => _selfEmployedManualIncomeEntries = value,
                              ),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('הזנת הוצאות עסקיות ידנית (עם +)'),
                              subtitle: const Text(
                                'כאשר פעיל, תתווסף אפשרות להוסיף הוצאות עסקיות לפי תאריך וסכום',
                              ),
                              value: _selfEmployedManualExpenseEntries,
                              onChanged: (value) => setState(
                                () => _selfEmployedManualExpenseEntries = value,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_selectedUserType == 'employee') ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _employeeCompensationType,
                        decoration: const InputDecoration(
                          labelText: 'שיטת שכר לשכיר',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'fixed',
                            child: Text('גלובלי (שכר חודשי קבוע)'),
                          ),
                          DropdownMenuItem(
                            value: 'hourly',
                            child: Text('שעתי (שכר לפי שעות)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _employeeCompensationType = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_employeeCompensationType == 'fixed')
                        TextField(
                          controller: _employeeFixedSalaryController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'שכר חודשי קבוע (₪)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      if (_employeeCompensationType == 'hourly')
                        TextField(
                          controller: _employeeHourlyRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'שכר לשעה (₪)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Card(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.35),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'הורדות קבועות מהברוטו',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'למשל פנסיה 10% — יקוזז מהברוטו לפני חישוב הנטו',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            if (_grossDeductions.isEmpty)
                              Text(
                                'אין הורדות מוגדרות',
                                style: theme.textTheme.bodyMedium,
                              ),
                            for (final deduction in _grossDeductions)
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(deduction.name),
                                  subtitle: Text(
                                    '${deduction.percentage.toStringAsFixed(deduction.percentage.truncateToDouble() == deduction.percentage ? 0 : 1)}% מהברוטו',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _openDeductionDialog(
                                          existing: deduction,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () {
                                          setState(() {
                                            _grossDeductions = _grossDeductions
                                                .where((d) => d.id != deduction.id)
                                                .toList();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _openDeductionDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('הוספת הורדה'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFixedMonthlyItemsCard(
                      theme: theme,
                      title: 'תוספות שכר קבועות',
                      subtitle:
                          'למשל נסיעות 500 ₪ — יתווסף אוטומטית לברוטו בכל חודש',
                      items: _fixedMonthlyAdditions,
                      type: 'addition',
                      addLabel: 'הוספת תוספת שכר',
                      emptyLabel: 'אין תוספות שכר קבועות',
                    ),
                    const SizedBox(height: 12),
                    _buildFixedMonthlyItemsCard(
                      theme: theme,
                      title: 'הוצאות קבועות חודשיות',
                      subtitle:
                          'למשל שכירות 2,000 ₪ — תתווסף אוטומטית להוצאות בכל חודש',
                      items: _fixedMonthlyExpenses,
                      type: 'expense',
                      addLabel: 'הוספת הוצאה קבועה',
                      emptyLabel: 'אין הוצאות קבועות',
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: theme.colorScheme.tertiaryContainer.withOpacity(0.35),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _savingsController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'אחוז חיסכון',
                            border: OutlineInputBorder(),
                            hintText: 'למשל 15.5',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('לקזז הוצאות אישיות מחישוב החיסכון'),
                      subtitle: const Text(
                        'כאשר פעיל, הוצאות אישיות חודשיות יופחתו מבסיס החישוב',
                      ),
                      value: _deductPersonalExpenses,
                      onChanged: (value) {
                        setState(() => _deductPersonalExpenses = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color:
                          theme.colorScheme.secondaryContainer.withOpacity(0.35),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _businessTabNameController,
                          decoration: const InputDecoration(
                            labelText: 'שם הטאב העסקי',
                            border: OutlineInputBorder(),
                            hintText: 'למשל: הכנסות / עסק / קליניקה',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(
                          BusinessProfessionCatalog.iconFromName(
                            _businessIconName,
                          ),
                        ),
                      ),
                      title: const Text('סמל תחום העיסוק'),
                      subtitle: Text(_professionLabel(_businessIconName)),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: _openProfessionPicker,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _personalCycleStartDay,
                      decoration: const InputDecoration(
                        labelText: 'יום התחלה למחזור הוצאות אישיות',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (var day = 1; day <= 28; day++)
                          DropdownMenuItem<int>(
                            value: day,
                            child: Text(
                              'מ-$day עד ${(day - 1 == 0) ? 'סוף חודש' : day - 1}',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _personalCycleStartDay = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _businessCycleStartDay,
                      decoration: const InputDecoration(
                        labelText: 'יום התחלה למחזור הכנסות',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (var day = 1; day <= 28; day++)
                          DropdownMenuItem<int>(
                            value: day,
                            child: Text(
                              'מ-$day עד ${(day - 1 == 0) ? 'סוף חודש' : day - 1}',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _businessCycleStartDay = value);
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('שמירה'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<FixedMonthlyItem> get _fixedMonthlyAdditions =>
      _fixedMonthlyItems.where((item) => item.isAddition).toList();

  List<FixedMonthlyItem> get _fixedMonthlyExpenses =>
      _fixedMonthlyItems.where((item) => item.isExpense).toList();

  Widget _buildFixedMonthlyItemsCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required List<FixedMonthlyItem> items,
    required String type,
    required String addLabel,
    required String emptyLabel,
  }) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(emptyLabel, style: theme.textTheme.bodyMedium),
            for (final item in items)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.amount.toStringAsFixed(0)} ₪ בכל חודש',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openFixedMonthlyDialog(
                          existing: item,
                          type: type,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() {
                            _fixedMonthlyItems = _fixedMonthlyItems
                                .where((entry) => entry.id != item.id)
                                .toList();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openFixedMonthlyDialog(type: type),
                icon: const Icon(Icons.add),
                label: Text(addLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openIncomeSourceDialog({IncomeSource? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final rateController = TextEditingController(
      text: existing == null
          ? ''
          : (existing.isHourly
                  ? existing.hourlyRate
                  : existing.fixedMonthlyAmount)
              .toStringAsFixed(0),
    );
    var payType = existing?.payType ?? 'hourly';
    var iconName = existing?.iconName ?? 'work';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(
            existing == null ? 'הוספת מקור הכנסה' : 'עריכת מקור הכנסה',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'שם העבודה',
                      hintText: 'למשל: בייביסיטר',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: payType,
                    decoration: const InputDecoration(
                      labelText: 'סוג תשלום',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'hourly',
                        child: Text('שעתי'),
                      ),
                      DropdownMenuItem(
                        value: 'fixedMonthly',
                        child: Text('קבוע חודשי'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() => payType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rateController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: payType == 'hourly'
                          ? 'שכר לשעה (₪)'
                          : 'סכום חודשי קבוע (₪)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'סמל',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in studentIncomeSourceIcons)
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setLocalState(() => iconName = option.id),
                          child: Container(
                            width: 72,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: iconName == option.id
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(option.icon, size: 22),
                                const SizedBox(height: 4),
                                Text(
                                  option.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
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
        ),
      ),
    );

    if (saved != true || !mounted) {
      nameController.dispose();
      rateController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final rate = double.tryParse(
          rateController.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    nameController.dispose();
    rateController.dispose();

    if (name.isEmpty || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש להזין שם וסכום חיובי')),
      );
      return;
    }

    final updated = IncomeSource(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      iconName: iconName,
      payType: payType,
      hourlyRate: payType == 'hourly' ? rate : 0,
      fixedMonthlyAmount: payType == 'fixedMonthly' ? rate : 0,
      isActive: true,
    );

    setState(() {
      if (existing == null) {
        _incomeSources = [..._incomeSources, updated];
      } else {
        _incomeSources = _incomeSources
            .map((item) => item.id == existing.id ? updated : item)
            .toList();
      }
    });
  }

  Future<void> _openFixedMonthlyDialog({
    FixedMonthlyItem? existing,
    required String type,
  }) async {
    final isAddition = type == 'addition';
    final nameController = TextEditingController(text: existing?.name ?? '');
    final amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(0),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null
              ? (isAddition ? 'הוספת תוספת שכר' : 'הוספת הוצאה קבועה')
              : (isAddition ? 'עריכת תוספת שכר' : 'עריכת הוצאה קבועה'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: isAddition ? 'שם התוספת' : 'שם ההוצאה',
                hintText: isAddition ? 'למשל: נסיעות' : 'למשל: שכירות',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'סכום חודשי (₪)',
                hintText: 'למשל 500',
                border: OutlineInputBorder(),
              ),
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
    );

    if (saved != true || !mounted) {
      nameController.dispose();
      amountController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final amount = double.tryParse(
          amountController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
    nameController.dispose();
    amountController.dispose();

    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש להזין שם וסכום חיובי')),
      );
      return;
    }

    final updated = FixedMonthlyItem(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      amount: amount,
      type: type,
    );

    setState(() {
      if (existing == null) {
        _fixedMonthlyItems = [..._fixedMonthlyItems, updated];
      } else {
        _fixedMonthlyItems = _fixedMonthlyItems
            .map((item) => item.id == existing.id ? updated : item)
            .toList();
      }
    });
  }

  Future<void> _openDeductionDialog({FixedGrossDeduction? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final percentController = TextEditingController(
      text: existing == null
          ? ''
          : existing.percentage.toStringAsFixed(
              existing.percentage.truncateToDouble() == existing.percentage
                  ? 0
                  : 1,
            ),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'הוספת הורדה' : 'עריכת הורדה'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'שם ההורדה',
                hintText: 'למשל: פנסיה',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: percentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'אחוז מהברוטו',
                hintText: 'למשל 10',
                border: OutlineInputBorder(),
              ),
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
    );

    if (saved != true || !mounted) {
      nameController.dispose();
      percentController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final percentage = double.tryParse(
          percentController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
    nameController.dispose();
    percentController.dispose();

    if (name.isEmpty || percentage <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש להזין שם ואחוז חיובי')),
      );
      return;
    }

    final updated = FixedGrossDeduction(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      percentage: percentage.clamp(0.01, 100.0),
    );

    setState(() {
      if (existing == null) {
        _grossDeductions = [..._grossDeductions, updated];
      } else {
        _grossDeductions = _grossDeductions
            .map((item) => item.id == existing.id ? updated : item)
            .toList();
      }
    });
  }

  Future<void> _openProfessionPicker() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('בחירת מקצוע / תחום'),
          content: SizedBox(
            width: 520,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: BusinessProfessionCatalog.professions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (context, index) {
                final p = BusinessProfessionCatalog.professions[index];
                final selected = p.id == _businessIconName;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).pop(p.id),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(p.icon),
                        const SizedBox(height: 6),
                        Text(
                          p.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() => _businessIconName = selected);
  }

  String _professionLabel(String id) {
    for (final p in BusinessProfessionCatalog.professions) {
      if (p.id == id) return p.label;
    }
    return 'בחר סמל';
  }
}
