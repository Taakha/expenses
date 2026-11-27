import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes/route_names.dart';
import '../../core/constants/app_icons.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/finance_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/screen_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;
    final finance = context.watch<FinanceController>();
    final name = user?.displayName?.trim();
    final shownName = name == null || name.isEmpty ? 'Money Wise user' : name;
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 28),
        children: [
          const ScreenHeader(
            title: 'More',
            subtitle: 'Your account, tools and preferences.',
          ),
          GlassContainer(
            padding: const EdgeInsets.all(17),
            radius: 21,
            blur: 9,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 29,
                  backgroundColor: AppColors.teal.withValues(alpha: 0.18),
                  child: Text(
                    shownName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.tealDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shownName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () =>
                      Navigator.pushNamed(context, RouteNames.settings),
                  icon: const Icon(AppIcons.editProfile),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          _ProfileLink(
            icon: AppIcons.accountCash,
            title: 'Accounts',
            subtitle: '${finance.activeAccounts.length} active accounts',
            onTap: () => Navigator.pushNamed(context, RouteNames.accounts),
          ),
          _ProfileLink(
            icon: AppIcons.notification,
            title: 'Notifications',
            subtitle:
                '${finance.notifications.where((item) => !item.isRead).length} unread',
            onTap: () => Navigator.pushNamed(context, RouteNames.notifications),
          ),
          _ProfileLink(
            icon: AppIcons.reports,
            title: 'Reports',
            subtitle: 'Review income, expenses and trends',
            onTap: () => Navigator.pushNamed(context, RouteNames.reports),
          ),
          _ProfileLink(
            icon: AppIcons.category,
            title: 'Categories',
            subtitle: 'Manage income and expense labels',
            onTap: () => Navigator.pushNamed(context, RouteNames.categories),
          ),
          _ProfileLink(
            icon: AppIcons.savingsGoal,
            title: 'Savings',
            subtitle: '${finance.goals.length} savings goals',
            onTap: () => Navigator.pushNamed(context, RouteNames.savings),
          ),
          _ProfileLink(
            icon: AppIcons.receipt,
            title: 'Receipts',
            subtitle: 'Browse transactions and attached receipts',
            onTap: () => Navigator.pushNamed(context, RouteNames.transactions),
          ),
          _ProfileLink(
            icon: AppIcons.debtBorrowed,
            title: 'Debts',
            subtitle: 'Track money owed and due',
            onTap: () => Navigator.pushNamed(context, RouteNames.debts),
          ),
          _ProfileLink(
            icon: AppIcons.recurring,
            title: 'Recurring',
            subtitle: 'Review scheduled transactions',
            onTap: () => Navigator.pushNamed(context, RouteNames.recurring),
          ),
          _ProfileLink(
            icon: AppIcons.conflict,
            title: 'Sync conflicts',
            subtitle: finance.conflicts.isEmpty
                ? 'All changes are in sync'
                : '${finance.conflicts.length} need review',
            onTap: () => Navigator.pushNamed(context, RouteNames.conflicts),
          ),
          _ProfileLink(
            icon: AppIcons.backup,
            title: 'Backup and restore',
            subtitle: 'Create a local data backup',
            onTap: () => Navigator.pushNamed(context, RouteNames.backup),
          ),
          _ProfileLink(
            icon: AppIcons.settings,
            title: 'Settings',
            subtitle: 'Appearance, currency and security',
            onTap: () => Navigator.pushNamed(context, RouteNames.settings),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await confirmAction(
                context,
                title: 'Sign out?',
                message: 'Your data will remain on this device and in your synced account.',
                confirmLabel: 'Sign out',
              );
              if (!confirmed || !context.mounted) return;
              try {
                await context.read<AuthService>().signOut();
              } catch (error) {
                if (context.mounted) {
                  showAppMessage(context, error.toString(), isError: true);
                }
              }
            },
            icon: const Icon(AppIcons.signOut),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        radius: 16,
        blur: 5,
        child: ListTile(
          leading: Icon(icon, color: AppColors.tealDark),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: const Icon(AppIcons.chevronRight),
          onTap: onTap,
        ),
      ),
    );
  }
}
