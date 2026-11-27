import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/core/services/finance_controller.dart';
import 'package:moneywise/core/services/financial_calculation_service.dart';
import 'package:moneywise/data/models/finance_models.dart';
import 'package:moneywise/data/repositories/finance_repository.dart';
import 'package:moneywise/data/synchronization/sync_service.dart';

void main() {
  test(
    'local changes complete without waiting for remote synchronization',
    () async {
      final repository = _FakeFinanceRepository();
      final syncService = _BlockingSyncService();
      final controller = FinanceController(
        repository: repository,
        syncService: syncService,
      )..userId = 'user-1';
      addTearDown(controller.dispose);

      final budget = _budget('budget-1');

      await controller.saveBudget(budget).timeout(const Duration(seconds: 2));

      expect(repository.savedBudget, same(budget));
      expect(controller.snapshot, isNotNull);
      await syncService.started.future.timeout(const Duration(seconds: 2));
      expect(syncService.requestedPullRemote, isFalse);
      expect(syncService.finished.isCompleted, isFalse);

      await controller
          .saveBudget(_budget('budget-2'))
          .timeout(const Duration(seconds: 2));
      syncService.release.complete();
      await syncService.finished.future;
      expect(syncService.syncCount, 2);
    },
  );
}

FinancialBudget _budget(String id) => FinancialBudget(
  id: id,
  userId: 'user-1',
  name: 'Accommodation',
  limitMinor: 500000,
  currencyCode: 'UGX',
  startDate: DateTime(2026, 11),
  endDate: DateTime(2026, 11, 30),
);

class _FakeFinanceRepository extends FinanceRepository {
  FinancialBudget? savedBudget;

  @override
  Future<void> saveBudget(FinancialBudget budget) async {
    savedBudget = budget;
  }

  @override
  Future<FinanceSnapshot> loadSnapshot(String uid) async => FinanceSnapshot(
    accounts: [],
    budgets: [],
    goals: [],
    contributions: [],
    debts: [],
    debtPayments: [],
    recurringRules: [],
    notifications: [],
    categories: [],
    recentTransactions: [],
    summary: FinancialSummary(
      incomeByCurrency: {},
      expensesByCurrency: {},
      balanceByCurrency: {},
    ),
    currentMonthSummary: FinancialSummary(
      incomeByCurrency: {},
      expensesByCurrency: {},
      balanceByCurrency: {},
    ),
    monthlySummaries: {},
    accountBalances: {},
    budgetProgress: {},
  );

  @override
  Future<String> preferredCurrency(String uid) async => 'UGX';

  @override
  Future<int> pendingSyncCount(String uid) async => 1;

  @override
  Future<List<Map<String, Object?>>> syncConflicts(String uid) async =>
      const [];
}

class _BlockingSyncService extends Fake implements SyncService {
  final started = Completer<void>();
  final release = Completer<void>();
  final finished = Completer<void>();

  bool? requestedPullRemote;
  var syncCount = 0;

  @override
  SyncState state = SyncState.synchronizing;

  @override
  String? lastError;

  @override
  int pendingCount = 1;

  @override
  Future<void> synchronize(String uid, {bool pullRemote = true}) async {
    syncCount++;
    requestedPullRemote = pullRemote;
    if (!started.isCompleted) started.complete();
    await release.future;
    state = SyncState.synced;
    pendingCount = 0;
    if (syncCount == 2 && !finished.isCompleted) finished.complete();
  }
}
