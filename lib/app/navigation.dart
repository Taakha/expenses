import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_icons.dart';
import '../core/services/finance_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/glass_scaffold.dart';
import '../features/budgets/budgets_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/transactions/quick_add_sheet.dart';
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
    final conflicts = context.watch<FinanceController>().conflicts.length;
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
          child: SizedBox(
            height: 72,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const sideInset = 5.0;
                const centerGap = 60.0;
                const markerInset = 4.0;
                final slotWidth =
                    (constraints.maxWidth - (sideInset * 2) - centerGap) / 4;
                final selectedSlot = switch (_index) {
                  0 => 0,
                  1 => 1,
                  2 => 2,
                  4 => 3,
                  _ => null,
                };
                final markerLeft = selectedSlot == null
                    ? 0.0
                    : selectedSlot < 2
                    ? sideInset + selectedSlot * slotWidth + markerInset
                    : sideInset +
                          2 * slotWidth +
                          centerGap +
                          (selectedSlot - 2) * slotWidth +
                          markerInset;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: dark
                              ? AppColors.darkCard.withValues(alpha: 0.97)
                              : AppColors.lightCard.withValues(alpha: 0.97),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: dark
                                ? Colors.white.withValues(alpha: 0.12)
                                : AppColors.teal.withValues(alpha: 0.14),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: dark ? 0.24 : 0.11,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            if (selectedSlot != null)
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 360),
                                curve: Curves.easeOutBack,
                                left: markerLeft,
                                top: markerInset,
                                bottom: markerInset,
                                width: slotWidth - markerInset * 2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.tealDark,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: sideInset,
                              ),
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
                                      label: 'Activity',
                                      onTap: _navigate,
                                    ),
                                  ),
                                  const SizedBox(width: centerGap),
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
                                      index: 4,
                                      selected: _index == 4,
                                      icon: AppIcons.profile,
                                      selectedIcon: AppIcons.profileFill,
                                      label: 'More',
                                      conflictCount: conflicts,
                                      onTap: _navigate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: (constraints.maxWidth - 50) / 2,
                      top: 0,
                      child: Semantics(
                        button: true,
                        label: 'Quick add transaction',
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: dark
                                  ? AppColors.darkCard
                                  : AppColors.lightCanvas,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: FilledButton(
                                onPressed: () =>
                                    showQuickAddTransaction(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.teal,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: const CircleBorder(),
                                  elevation: 3,
                                  shadowColor: AppColors.teal.withValues(
                                    alpha: 0.28,
                                  ),
                                ),
                                child: const Icon(
                                  AppIcons.contribute,
                                  size: 23,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
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
    this.conflictCount = 0,
  });

  final int index;
  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final ValueChanged<int> onTap;
  final int conflictCount;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkMuted
        : AppColors.lightText;
    return Semantics(
      button: true,
      selected: selected,
      label: conflictCount > 0
          ? '$label, $conflictCount sync conflicts need review'
          : label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => onTap(index),
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      selected ? selectedIcon : icon,
                      color: selected ? Colors.white : inactiveColor,
                      size: 19,
                    ),
                    if (conflictCount > 0)
                      Positioned(
                        right: -7,
                        top: -4,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: AppColors.expense,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? AppColors.teal
                                  : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.darkCard
                                        : AppColors.lightCard),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : inactiveColor,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
