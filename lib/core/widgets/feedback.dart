import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../theme/app_colors.dart';
import 'glass_container.dart';

void showAppMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.expense : AppColors.tealDeep,
      ),
    );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Continue',
  bool destructive = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: AppColors.expense)
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({
    required this.state,
    required this.pending,
    super.key,
    this.onTap,
  });

  final String state;
  final int pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isOffline = state == 'offline';
    final isError   = state == 'needsAttention';
    final color = isOffline ? AppColors.amber
        : isError ? AppColors.expense
        : AppColors.teal;
    final icon = isOffline ? AppIcons.syncOffline
        : isError ? AppIcons.syncError
        : state == 'synchronizing' ? AppIcons.syncPending
        : AppIcons.syncDone;
    final label = switch (state) {
      'offline'          => 'Offline · changes saved on this device',
      'synchronizing'    => 'Syncing your changes…',
      'needsAttention'   => 'Sync needs attention',
      _                  => pending == 0
          ? 'All changes synchronized'
          : '$pending change${pending == 1 ? '' : 's'} waiting to sync',
    };

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        radius: 13,
        blur: 7,
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            if (state == 'synchronizing')
              const SizedBox.square(
                dimension: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
