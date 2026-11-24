import 'package:flutter/material.dart';

import '../core/constants/app_icons.dart';
import '../core/widgets/glass_scaffold.dart';
import '../features/budgets/budgets_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/transactions/transactions_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _index = 0;

  void _navigate(int index) {
    if (index >= 0 && index < 5) setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      GlassScaffold(
        padding: EdgeInsets.zero,
        child: DashboardScreen(onNavigate: _navigate),
      ),
      const TransactionsScreen(),
      const BudgetsScreen(),
      const ReportsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon:         Icon(AppIcons.home),
            selectedIcon: Icon(AppIcons.homeFill),
            label: 'Home',
          ),
          NavigationDestination(
            icon:         Icon(AppIcons.activity),
            selectedIcon: Icon(AppIcons.activityFill),
            label: 'Activity',
          ),
          NavigationDestination(
            icon:         Icon(AppIcons.budgets),
            selectedIcon: Icon(AppIcons.budgetsFill),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon:         Icon(AppIcons.reports),
            selectedIcon: Icon(AppIcons.reportsFill),
            label: 'Reports',
          ),
          NavigationDestination(
            icon:         Icon(AppIcons.profile),
            selectedIcon: Icon(AppIcons.profileFill),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
