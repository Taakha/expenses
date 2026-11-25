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
          ScreenHeader(
            title: 'More',
            subtitle: 'Your account, tools and preferences.',
            trailing: IconButton(
              tooltip: 'Settings',
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.settings),
              icon: const Icon(AppIcons.settings),
            ),
          ),
          GlassContainer(
            padding: const EdgeInsets.all(13),
            radius: 17,
            blur: 7,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.teal.withValues(alpha: 0.18),
                  child: Text(
                    shownName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.tealDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shownName,
                        style: Theme.of(context).textTheme.titleMedium,
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
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 1.8,
            children: [
              _MoreFeatureCard(
                icon: AppIcons.savingsGoal,
                title: 'Savings Goals',
                subtitle: '${finance.goals.length} goals',
                onTap: () => Navigator.pushNamed(context, RouteNames.savings),
              ),
              _MoreFeatureCard(
                icon: AppIcons.debtBorrowed,
                title: 'Debt Tracking',
                subtitle: 'Manage balances',
                onTap: () => Navigator.pushNamed(context, RouteNames.debts),
              ),
              _MoreFeatureCard(
                icon: AppIcons.recurring,
                title: 'Recurring',
                subtitle: 'Scheduled transactions',
                onTap: () => Navigator.pushNamed(context, RouteNames.recurring),
              ),
              _MoreFeatureCard(
                icon: AppIcons.category,
                title: 'Categories',
                subtitle: 'Manage labels',
                onTap: () =>
                    Navigator.pushNamed(context, RouteNames.categories),
              ),
              _MoreFeatureCard(
                icon: AppIcons.accountCash,
                title: 'Accounts',
                subtitle: '${finance.activeAccounts.length} active',
                onTap: () => Navigator.pushNamed(context, RouteNames.accounts),
              ),
              _MoreFeatureCard(
                icon: AppIcons.receipt,
                title: 'Receipts',
                subtitle: 'View attachments',
                onTap: () =>
                    Navigator.pushNamed(context, RouteNames.transactions),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProfileLink(
            icon: AppIcons.notification,
            title: 'Notifications',
            subtitle:
                '${finance.notifications.where((item) => !item.isRead).length} unread',
            onTap: () => Navigator.pushNamed(context, RouteNames.notifications),
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

class _MoreFeatureCard extends StatelessWidget {
  const _MoreFeatureCard({
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
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 16,
      blur: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.tealDark, size: 21),
            const SizedBox(height: 5),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
