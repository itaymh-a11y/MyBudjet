import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/business_professions.dart';
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
