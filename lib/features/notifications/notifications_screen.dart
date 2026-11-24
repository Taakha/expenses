import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/finance_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/screen_header.dart';
import '../../data/models/finance_models.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final notifications = finance.notifications;
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 25),
        children: [
          ScreenHeader(
            title: 'Notifications',
            subtitle: notifications.isEmpty
                ? 'You are all caught up.'
                : '${notifications.where((item) => !item.isRead).length} unread updates',
            trailing: notifications.any((item) => !item.isRead)
                ? TextButton(
                    onPressed: () async {
                      try {
                        await finance.markAllNotificationsRead();
                      } catch (error) {
                        if (context.mounted) showAppMessage(context, error.toString(), isError: true);
                      }
                    },
                    child: const Text('Mark all read'),
                  )
                : null,
            showBack: true,
          ),
          if (notifications.isEmpty)
            const GlassEmptyState(
              title: 'No notifications yet',
              message: 'Budget alerts and account updates will appear here.',
              icon: Icons.notifications_none_rounded,
            )
          else
            ...notifications.map(
              (notification) => _NotificationCard(notification: notification),
            ),
          const SizedBox(height: 8),
          const _LocalNotificationNote(),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceController>();
    final color = notification.type == 'budget'
        ? AppColors.amber
        : AppColors.teal;
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(17),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
      ),
      confirmDismiss: (_) async {
        return confirmAction(
          context,
          title: 'Delete notification?',
          message: 'This will remove it from this device and your synced account.',
          confirmLabel: 'Delete',
        );
      },
      onDismissed: (_) async {
        try {
          await finance.deleteNotification(notification.id);
        } catch (error) {
          if (context.mounted) showAppMessage(context, error.toString(), isError: true);
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassContainer(
          padding: EdgeInsets.zero,
          radius: 17,
          blur: 6,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(
                notification.type == 'budget'
                    ? Icons.pie_chart_outline_rounded
                    : Icons.notifications_active_outlined,
                color: color,
              ),
            ),
            title: Text(
              notification.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w800,
                  ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${notification.body}\n${_dateTime(notification.createdAt)}'),
            ),
            isThreeLine: true,
            trailing: notification.isRead
                ? null
                : const Icon(Icons.circle, size: 9, color: AppColors.teal),
            onTap: notification.isRead
                ? null
                : () async {
                    try {
                      await finance.markNotificationRead(notification.id);
                    } catch (error) {
                      if (context.mounted) showAppMessage(context, error.toString(), isError: true);
                    }
                  },
          ),
        ),
      ),
    );
  }
}

class _LocalNotificationNote extends StatelessWidget {
  const _LocalNotificationNote();

  @override
  Widget build(BuildContext context) => GlassContainer(
    padding: const EdgeInsets.all(12),
    radius: 15,
    blur: 5,
    child: Text(
      'Notifications are stored on your device. Budget threshold alerts are generated locally when a new expense is recorded.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

String _dateTime(DateTime value) =>
    '${value.day}/${value.month}/${value.year} at ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
