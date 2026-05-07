import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/business_professions.dart';
import '../../core/repositories/providers.dart';
import 'home_tab.dart';
import '../personal/personal_expenses_screen.dart';
import '../pension/pension_screen.dart';
import '../savings/savings_plan_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(firebaseAuthProvider);
    final user = auth.currentUser;
    final userProfileAsync = ref.watch(currentUserProfileProvider);
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

    final pages = <Widget>[
      HomeTab(
        onGoToPersonal: () => setState(() => _currentIndex = 1),
        onGoToPension: () => setState(() => _currentIndex = 2),
        onGoToSavings: () => setState(() => _currentIndex = 3),
      ),
      const PersonalExpensesScreen(),
      const PensionScreen(),
      const SavingsPlanScreen(),
    ];

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('MyBudget - ${user?.email ?? ''}'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune),
                  label: const Text('הגדרות'),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout),
                  tooltip: 'התנתק',
                ),
              ],
            ),
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'בית',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'אישי',
          ),
          NavigationDestination(
            icon: Icon(
              BusinessProfessionCatalog.iconFromName(businessIconName),
            ),
            selectedIcon: Icon(
              BusinessProfessionCatalog.iconFromName(businessIconName),
              color: colorScheme.primary,
            ),
            label: businessTabName,
          ),
          const NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'חיסכון',
          ),
        ],
      ),
    );
  }
}
