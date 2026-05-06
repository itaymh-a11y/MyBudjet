import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _savingsController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String _selectedUserType = 'selfEmployed';

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  @override
  void dispose() {
    _savingsController.dispose();
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
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final authUser = ref.read(firebaseAuthProvider).currentUser;
    if (authUser == null) return;

    final raw = _savingsController.text.trim();
    final parsed = double.tryParse(raw);
    final percentage = parsed ?? 0.0;

    setState(() => _isSaving = true);
    try {
      await ref.read(userRepositoryProvider).updateUserSettings(
            userId: authUser.uid,
            userType: _selectedUserType,
            savingsPercentage: percentage,
          );

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'סוג משתמש',
                      style: theme.textTheme.titleMedium,
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
                    const SizedBox(height: 16),
                    TextField(
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
                    const Spacer(),
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
}
