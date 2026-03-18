import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/providers.dart';
import 'home_tab.dart';
import '../personal/personal_expenses_screen.dart';
import '../pension/pension_screen.dart';

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

    final pages = <Widget>[
      HomeTab(
        onGoToPersonal: () => setState(() => _currentIndex = 1),
        onGoToPension: () => setState(() => _currentIndex = 2),
      ),
      const PersonalExpensesScreen(),
      const PensionScreen(),
      Center(
        child: Text(
          'כאן יופיע מסך ההגדרות (בשלב מאוחר יותר)',
          textAlign: TextAlign.center,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('MyBudget - ${user?.email ?? ''}'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'התנתק',
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'בית',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'אישי',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: 'פנסיון',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'הגדרות',
          ),
        ],
      ),
    );
  }
}
