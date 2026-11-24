import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/finance_models.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/synchronization/sync_service.dart';
import 'financial_calculation_service.dart';

class FinanceController extends ChangeNotifier {
  FinanceController({
    FinanceRepository? repository,
    SyncService? syncService,
    Connectivity? connectivity,
    FinancialCalculationService calculations =
        const FinancialCalculationService(),
  }) : _repository = repository ?? FinanceRepository(),
       _syncService = syncService ?? SyncService(),
       _connectivity = connectivity ?? Connectivity(),
       _calculations = calculations;

  final FinanceRepository _repository;
  final SyncService _syncService;
  final Connectivity _connectivity;
  final FinancialCalculationService _calculations;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  String? userId;
  String preferredCurrency = 'UGX';
  FinanceSnapshot? snapshot;
  bool isLoading = false;
  SyncState syncState = SyncState.offline;
  String? syncError;
  String? lastError;
  int pendingSyncCount = 0;
  List<Map<String, Object?>> conflicts = const [];

  bool isReadyFor(String uid) =>
      userId == uid && snapshot != null && !isLoading;

  List<FinancialAccount> get accounts =>
      snapshot?.accounts ?? const <FinancialAccount>[];
  List<FinancialAccount> get activeAccounts =>
      accounts.where((account) => !account.isArchived).toList();
  List<FinancialTransaction> get transactions =>
      snapshot?.transactions ?? const <FinancialTransaction>[];
  List<FinancialBudget> get budgets =>
      snapshot?.budgets ?? const <FinancialBudget>[];
  List<SavingsGoal> get goals => snapshot?.goals ?? const <SavingsGoal>[];
  List<SavingsContribution> get contributions =>
      snapshot?.contributions ?? const <SavingsContribution>[];
  List<DebtRecord> get debts => snapshot?.debts ?? const <DebtRecord>[];
  List<RecurringRule> get recurringRules =>
      snapshot?.recurringRules ?? const <RecurringRule>[];
  List<AppNotification> get notifications =>
      snapshot?.notifications ?? const <AppNotification>[];
  List<Map<String, Object?>> get categories =>
      snapshot?.categories ?? const <Map<String, Object?>>[];

  FinancialSummary get summary =>
      _calculations.summarize(accounts: accounts, transactions: transactions);

  FinancialSummary summaryFor({DateTime? from, DateTime? through}) =>
      _calculations.summarize(
        accounts: accounts,
        transactions: transactions,
        from: from,
        through: through,
      );

  FinancialSummary summarizeTransactions(
    List<FinancialTransaction> transactions, {
    DateTime? from,
    DateTime? through,
  }) => _calculations.summarize(
    accounts: const [],
    transactions: transactions,
    from: from,
    through: through,
  );

  List<CategorySpending> categorySpending({
    required String currencyCode,
    DateTime? from,
    DateTime? through,
  }) => _calculations.categorySpending(
    transactions,
    currencyCode: currencyCode,
    from: from,
    through: through,
  );

  int accountBalance(FinancialAccount account) =>
      _calculations.accountBalance(account, transactions);

  BudgetProgress budgetProgress(FinancialBudget budget) =>
      _calculations.budgetProgress(budget: budget, transactions: transactions);

  int savingsTotal(SavingsGoal goal) =>
      _calculations.savingsTotal(goal.id, contributions);

  int debtOutstanding(DebtRecord debt) => _calculations.outstandingDebt(
    debt,
    snapshot?.debtPayments ?? const <DebtPayment>[],
  );

  Future<void> initialize({
    required String uid,
    required String email,
    required String fullName,
    String currencyCode = 'UGX',
    String? phoneNumber,
  }) async {
    if (userId == uid && (isLoading || snapshot != null)) return;
    userId = uid;
    isLoading = true;
    lastError = null;
    notifyListeners();
    try {
      await _repository.ensureUser(
        uid: uid,
        email: email,
        fullName: fullName,
        currencyCode: currencyCode,
        phoneNumber: phoneNumber,
      );
      preferredCurrency = await _repository.preferredCurrency(uid);
      try {
        await _repository.processDueRecurring(uid);
      } on FinanceException catch (error) {
        lastError = error.message;
      }
      await refresh();
      await syncNow();
      _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen((
        results,
      ) {
        if (results.any((result) => result != ConnectivityResult.none)) {
          unawaited(syncNow());
        }
      });
    } catch (error) {
      lastError = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final uid = userId;
    if (uid == null) return;
    snapshot = await _repository.loadSnapshot(uid);
    preferredCurrency = await _repository.preferredCurrency(uid);
    pendingSyncCount = (await _repository.pendingSync(uid)).length;
    conflicts = await _repository.syncConflicts(uid);
    notifyListeners();
  }

  Future<void> syncNow() async {
    final uid = userId;
    if (uid == null) return;
    await _syncService.synchronize(uid);
    syncState = _syncService.state;
    syncError = _syncService.lastError;
    pendingSyncCount = _syncService.pendingCount;
    conflicts = await _repository.syncConflicts(uid);
    await refresh();
  }

  Future<void> saveAccount(FinancialAccount account) =>
      _run(() => _repository.saveAccount(account));

  Future<void> archiveAccount(String id) =>
      _run(() => _repository.archiveAccount(_requireUid(), id));

  Future<void> saveTransaction(FinancialTransaction transaction) async {
    await _run(() => _repository.saveTransaction(transaction));
    await _createBudgetAlerts();
  }

  Future<void> deleteTransaction(String id) =>
      _run(() => _repository.voidTransaction(_requireUid(), id));

  Future<void> saveBudget(FinancialBudget budget) =>
      _run(() => _repository.saveBudget(budget));

  Future<void> deleteBudget(String id) =>
      _run(() => _repository.archiveBudget(_requireUid(), id));

  Future<void> saveGoal(SavingsGoal goal) =>
      _run(() => _repository.saveGoal(goal));

  Future<void> contribute({
    required String goalId,
    required int amountMinor,
    required String currencyCode,
    required bool withdrawal,
    String? accountId,
    String notes = '',
  }) => _run(
    () => _repository.saveContribution(
      SavingsContribution(
        id: FinanceRepository.createId(),
        userId: _requireUid(),
        goalId: goalId,
        amountMinor: amountMinor,
        currencyCode: currencyCode,
        type: withdrawal ? 'withdrawal' : 'contribution',
        occurredAt: DateTime.now(),
        accountId: accountId,
        notes: notes,
      ),
    ),
  );

  Future<void> pauseGoal(String id) =>
      _run(() => _repository.archiveGoal(_requireUid(), id));

  Future<void> saveDebt(DebtRecord debt) =>
      _run(() => _repository.saveDebt(debt));

  Future<void> recordDebtPayment({
    required String debtId,
    required int amountMinor,
    required String paymentType,
    String? accountId,
    String notes = '',
  }) => _run(
    () => _repository.saveDebtPayment(
      uid: _requireUid(),
      debtId: debtId,
      paymentId: FinanceRepository.createId(),
      amountMinor: amountMinor,
      paymentType: paymentType,
      date: DateTime.now(),
      accountId: accountId,
      notes: notes,
    ),
  );

  Future<void> saveRecurring(RecurringRule rule) =>
      _run(() => _repository.saveRecurringRule(rule));

  Future<void> saveCategory({required String name, required String type}) =>
      _run(
        () => _repository.saveCategory(
          uid: _requireUid(),
          id: FinanceRepository.createId(),
          name: name,
          type: type,
        ),
      );

  Future<void> archiveCategory(String id) =>
      _run(() => _repository.archiveCategory(_requireUid(), id));

  Future<void> markNotificationRead(String id) =>
      _run(() => _repository.markNotificationRead(_requireUid(), id));

  Future<void> markAllNotificationsRead() =>
      _run(() => _repository.markAllNotificationsRead(_requireUid()));

  Future<void> deleteNotification(String id) =>
      _run(() => _repository.deleteNotification(_requireUid(), id));

  Future<void> setCurrency(String code) async {
    await _repository.setPreferredCurrency(_requireUid(), code);
    preferredCurrency = code;
    notifyListeners();
    await syncNow();
  }

  Future<void> resolveConflict({
    required Map<String, Object?> conflict,
    required bool keepLocal,
  }) async {
    await _repository.resolveSyncConflict(
      uid: _requireUid(),
      collection: conflict['collection_name']! as String,
      recordId: conflict['record_id']! as String,
      keepLocal: keepLocal,
    );
    await syncNow();
  }

  Future<void> _run(Future<void> Function() action) async {
    lastError = null;
    try {
      await action();
      await refresh();
      await syncNow();
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _createBudgetAlerts() async {
    final uid = userId;
    if (uid == null) return;
    for (final budget in budgets) {
      final progress = budgetProgress(budget);
      final threshold = progress.usagePercent >= 100
          ? 100
          : progress.usagePercent >= 90
          ? 90
          : progress.usagePercent >= budget.alertPercentage
          ? budget.alertPercentage
          : 0;
      if (threshold == 0) continue;
      final periodKey =
          '${budget.startDate.year}_${budget.startDate.month}_${budget.id}_$threshold';
      await _repository.saveNotification(
        AppNotification(
          id: 'budget_$periodKey',
          userId: uid,
          title: threshold >= 100 ? 'Budget exceeded' : 'Budget getting low',
          body: '${budget.name} is at ${progress.usagePercent}% of its limit.',
          type: 'budget',
          createdAt: DateTime.now(),
        ),
      );
    }
    await refresh();
    await syncNow();
  }

  String _requireUid() {
    final uid = userId;
    if (uid == null) throw StateError('A signed-in account is required.');
    return uid;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
