import 'package:flutter/material.dart';

import '../core/constants/app_icons.dart';
import '../core/widgets/glass_scaffold.dart';
import '../features/budgets/budgets_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/transactions/quick_add_sheet.dart';
import '../features/transactions/transactions_screen.dart';
import '../core/theme/app_colors.dart';

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

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 64,
                  color: dark
                      ? AppColors.darkCard.withValues(alpha: 0.96)
                      : AppColors.lightCard.withValues(alpha: 0.96),
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavDestination(
                          index: 0,
                          selected: _index == 0,
                          icon: AppIcons.home,
                          selectedIcon: AppIcons.homeFill,
                          label: 'Home',
                          onTap: _navigate,
                        ),
                      ),
                      Expanded(
                        child: _NavDestination(
                          index: 1,
                          selected: _index == 1,
                          icon: AppIcons.activity,
                          selectedIcon: AppIcons.activityFill,
                          label: 'Transactions',
                          onTap: _navigate,
                        ),
                      ),
                      const SizedBox(width: 68),
                      Expanded(
                        child: _NavDestination(
                          index: 2,
                          selected: _index == 2,
                          icon: AppIcons.budgets,
                          selectedIcon: AppIcons.budgetsFill,
                          label: 'Budgets',
                          onTap: _navigate,
                        ),
                      ),
                      Expanded(
                        child: _NavDestination(
                          index: 3,
                          selected: _index == 3,
                          icon: AppIcons.reports,
                          selectedIcon: AppIcons.reportsFill,
                          label: 'Reports',
                          onTap: _navigate,
                        ),
                      ),
                      Expanded(
                        child: _NavDestination(
                          index: 4,
                          selected: _index == 4,
                          icon: AppIcons.profile,
                          selectedIcon: AppIcons.profileFill,
                          label: 'More',
                          onTap: _navigate,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: Semantics(
                  button: true,
                  label: 'Quick add transaction',
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: FilledButton(
                      onPressed: () => showQuickAddTransaction(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        elevation: 4,
                        shadowColor: AppColors.teal.withValues(alpha: 0.32),
                      ),
                      child: const Icon(AppIcons.contribute, size: 26),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.index,
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.teal
        : Theme.of(context).textTheme.bodySmall?.color ?? AppColors.lightText;
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? selectedIcon : icon, color: color, size: 21),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
