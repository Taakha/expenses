import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_icons.dart';
import '../../core/services/finance_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/screen_header.dart';

class ConflictsScreen extends StatefulWidget {
  const ConflictsScreen({super.key});

  @override
  State<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends State<ConflictsScreen> {
  int _current = 0;
  bool _busy = false;
  // tracks per-conflict choices for the done summary
  final _choices = <String>[];

  Future<void> _resolve(
    Map<String, Object?> conflict, {
    required _ConflictChoice choice,
  }) async {
    final finance = context.read<FinanceController>();
    setState(() => _busy = true);
    try {
      if (choice == _ConflictChoice.keepBoth) {
        await finance.keepBothTransactionConflict(conflict: conflict);
        _choices.add('Kept both');
      } else {
        await finance.resolveConflict(
          conflict: conflict,
          keepLocal: choice == _ConflictChoice.keepLocal,
        );
        _choices.add(
          choice == _ConflictChoice.keepLocal
              ? 'Kept this phone'
              : 'Kept other device',
        );
      }
      if (mounted) {
        final remaining = finance.conflicts.length;
        if (remaining == 0) {
          setState(() {}); // show done state
        } else {
          setState(() => _current = (_current).clamp(0, remaining - 1));
        }
      }
    } catch (e) {
      if (mounted) showAppMessage(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = context.watch<FinanceController>().conflicts;
    final currentIndex = conflicts.isEmpty
        ? 0
        : _current.clamp(0, conflicts.length - 1);

    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          const ScreenHeader(
            title: 'Review changes',
            subtitle: 'Nothing is deleted until you choose.',
            showBack: true,
          ),
          if (conflicts.isEmpty) ...[
            _DoneState(choices: _choices),
          ] else ...[
            // ── Progress ──────────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  '${currentIndex + 1} of ${conflicts.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (currentIndex + 1) / conflicts.length,
                      minHeight: 5,
                      color: AppColors.teal,
                      backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Conflict card ─────────────────────────────────────────────────
            _ConflictCard(
              conflict: conflicts[currentIndex],
              busy: _busy,
              onKeepLocal: () => _resolve(
                conflicts[currentIndex],
                choice: _ConflictChoice.keepLocal,
              ),
              onKeepRemote: () => _resolve(
                conflicts[currentIndex],
                choice: _ConflictChoice.keepRemote,
              ),
              onKeepBoth: () => _resolve(
                conflicts[currentIndex],
                choice: _ConflictChoice.keepBoth,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _ConflictChoice { keepLocal, keepRemote, keepBoth }

// ── Conflict card ─────────────────────────────────────────────────────────────

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.busy,
    required this.onKeepLocal,
    required this.onKeepRemote,
    required this.onKeepBoth,
  });

  final Map<String, Object?> conflict;
  final bool busy;
  final VoidCallback onKeepLocal;
  final VoidCallback onKeepRemote;
  final VoidCallback onKeepBoth;

  @override
  Widget build(BuildContext context) {
    final local = _decode(conflict['local_record'] as String? ?? '{}');
    final remote = _decode(conflict['remote_record'] as String? ?? '{}');
    final collection = conflict['collection_name'] as String? ?? '';
    final finance = context.watch<FinanceController>();
    final accountNames = {
      for (final account in finance.accounts) account.id: account.name,
    };

    // Find which fields differ (exclude metadata)
    const skip = {
      'id',
      'user_id',
      'sync_status',
      'updated_at',
      'created_at',
      'deleted_at',
      'version',
      'receipt_path',
    };
    final diffKeys = <String>{};
    for (final key in {...local.keys, ...remote.keys}) {
      if (skip.contains(key)) continue;
      if (local[key].toString() != remote[key].toString()) diffKeys.add(key);
    }

    // Priority display fields (shown first)
    const priority = [
      'description',
      'amount_minor',
      'transaction_date',
      'account_id',
      'destination_account_id',
      'type',
      'category',
      'name',
      'limit_minor',
      'target_minor',
      'status',
    ];
    final allKeys = [
      ...priority.where((k) => local.containsKey(k) || remote.containsKey(k)),
      ...{
        ...local.keys,
        ...remote.keys,
      }.where((k) => !priority.contains(k) && !skip.contains(k)),
    ].take(8).toList();

    final localTime = _timestamp(local['updated_at']);
    final remoteTime = _timestamp(remote['updated_at']);
    final canKeepBoth =
        collection == 'transactions' &&
        local['status'] == 'active' &&
        remote['status'] == 'active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Collection label ──────────────────────────────────────────────────
        Row(
          children: [
            const Icon(AppIcons.conflict, size: 15, color: AppColors.amber),
            const SizedBox(width: 6),
            Text(
              _collectionLabel(collection),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Two-column comparison ─────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _VersionCard(
                label: 'This phone',
                subtitle: localTime,
                data: local,
                displayKeys: allKeys,
                diffKeys: diffKeys,
                accountNames: accountNames,
                accent: AppColors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VersionCard(
                label: 'Other device',
                subtitle: remoteTime,
                data: remote,
                displayKeys: allKeys,
                diffKeys: diffKeys,
                accountNames: accountNames,
                accent: AppColors.violet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Buttons ───────────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : onKeepLocal,
            icon: const Icon(AppIcons.checkmark, size: 16),
            label: const Text('Keep this phone'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : onKeepRemote,
            icon: const Icon(AppIcons.syncDone, size: 16),
            label: const Text('Keep other device'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: busy || !canKeepBoth ? null : onKeepBoth,
            icon: const Icon(AppIcons.contribute, size: 16),
            label: Text(
              canKeepBoth
                  ? 'Keep both as separate entries'
                  : 'Keep both (active transactions only)',
            ),
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 14),
          const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ],
    );
  }

  static Map<String, dynamic> _decode(String json) {
    try {
      final v = jsonDecode(json);
      return v is Map<String, dynamic> ? v : {};
    } on FormatException {
      return {};
    }
  }

  static String _collectionLabel(String c) => switch (c) {
    'transactions' => 'Transaction',
    'budgets' => 'Budget',
    'savings_goals' => 'Savings goal',
    'savings_contributions' => 'Savings contribution',
    'accounts' => 'Account',
    'debts' => 'Debt',
    _ => c.replaceAll('_', ' '),
  };

  static String _timestamp(Object? ms) {
    if (ms is! int) return 'unknown time';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Version card ──────────────────────────────────────────────────────────────

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.label,
    required this.subtitle,
    required this.data,
    required this.displayKeys,
    required this.diffKeys,
    required this.accountNames,
    required this.accent,
  });

  final String label;
  final String subtitle;
  final Map<String, dynamic> data;
  final List<String> displayKeys;
  final Set<String> diffKeys;
  final Map<String, String> accountNames;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      radius: 16,
      blur: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Last edited $subtitle',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 14),
          // Fields
          ...displayKeys.map((key) {
            final value = _fmt(key, data, accountNames);
            final differs = diffKeys.contains(key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: differs
                    ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
                    : EdgeInsets.zero,
                decoration: differs
                    ? BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.5),
                        ),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fieldLabel(key),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: differs ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _fieldLabel(String key) => switch (key) {
    'amount_minor' => 'Amount',
    'transaction_date' => 'Date',
    'account_id' => 'From wallet',
    'destination_account_id' => 'To wallet',
    'description' => 'Description',
    'type' => 'Type',
    'category' => 'Category',
    'limit_minor' => 'Limit',
    'target_minor' => 'Target',
    'name' => 'Name',
    'status' => 'Status',
    _ => key.replaceAll('_', ' '),
  };

  static String _fmt(
    String key,
    Map<String, dynamic> data,
    Map<String, String> accountNames,
  ) {
    final value = data[key];
    if (value == null) return '—';
    if (key == 'amount_minor' && value is int) {
      final currency = data['currency_code'] as String? ?? 'UGX';
      final type = data['type'] as String?;
      final sign = switch (type) {
        'income' || 'refund' => '+',
        'expense' => '−',
        _ => '',
      };
      return '$sign${formatMinorUnits(value, currency)}';
    }
    if ((key == 'limit_minor' || key == 'target_minor') && value is int) {
      return formatMinorUnits(value, data['currency_code'] as String? ?? 'UGX');
    }
    if ((key == 'account_id' || key == 'destination_account_id') &&
        value is String) {
      return accountNames[value] ?? 'Wallet unavailable on this device';
    }
    if (key.endsWith('_date') || key == 'updated_at' || key == 'created_at') {
      if (value is int) {
        final dt = DateTime.fromMillisecondsSinceEpoch(value);
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    }
    return value.toString();
  }
}

// ── Done state ────────────────────────────────────────────────────────────────

class _DoneState extends StatelessWidget {
  const _DoneState({required this.choices});

  final List<String> choices;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(AppIcons.goalComplete, color: AppColors.income, size: 44),
          const SizedBox(height: 12),
          Text('All caught up', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Your financial data is consistent across devices.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (choices.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...choices.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      AppIcons.checkmark,
                      size: 13,
                      color: AppColors.income,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Conflict ${e.key + 1}: ${e.value}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(AppIcons.checkmark, size: 16),
              label: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
