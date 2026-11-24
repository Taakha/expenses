import 'package:flutter/material.dart';

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
    final color = isOffline ? AppColors.amber : AppColors.teal;
    final label = switch (state) {
      'offline' => 'Offline · changes saved on this device',
      'synchronizing' => 'Syncing your changes…',
      'needsAttention' => 'Sync needs attention',
      _ =>
        pending == 0
            ? 'All changes synchronized'
            : '$pending changes waiting to sync',
    };
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        radius: 14,
        blur: 8,
        child: Row(
          children: [
            Icon(
              isOffline ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            if (state == 'synchronizing')
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
