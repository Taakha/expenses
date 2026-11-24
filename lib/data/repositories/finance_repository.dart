import 'dart:math';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/services/financial_calculation_service.dart';
import '../local/app_database.dart';
import '../models/finance_models.dart';

class FinanceException implements Exception {
  const FinanceException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

class FinanceSnapshot {
  const FinanceSnapshot({
    required this.accounts,
    required this.budgets,
    required this.goals,
    required this.contributions,
    required this.debts,
    required this.debtPayments,
    required this.recurringRules,
    required this.notifications,
    required this.categories,
    required this.recentTransactions,
    required this.summary,
    required this.currentMonthSummary,
    required this.monthlySummaries,
    required this.accountBalances,
    required this.budgetProgress,
  });

  final List<FinancialAccount> accounts;
  final List<FinancialBudget> budgets;
  final List<SavingsGoal> goals;
  final List<SavingsContribution> contributions;
  final List<DebtRecord> debts;
  final List<DebtPayment> debtPayments;
  final List<RecurringRule> recurringRules;
  final List<AppNotification> notifications;
  final List<Map<String, Object?>> categories;
  final List<FinancialTransaction> recentTransactions;
  final FinancialSummary summary;
  final FinancialSummary currentMonthSummary;
  final Map<String, FinancialSummary> monthlySummaries;
  final Map<String, int> accountBalances;
  final Map<String, BudgetProgress> budgetProgress;
}

class TransactionPage {
  const TransactionPage({
    required this.transactions,
    required this.hasMore,
  });

  final List<FinancialTransaction> transactions;
  final bool hasMore;
}

class FinanceRepository {
  FinanceRepository({
    AppDatabase? database,
    this._calculations =
        const FinancialCalculationService(),
  }) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;
  final FinancialCalculationService _calculations;

  static const syncCollections = <String>[
    'accounts',
    'transactions',
    'budgets',
    'savings_goals',
    'savings_contributions',
    'debts',
    'debt_payments',
    'recurring_transactions',
    'categories',
    'notifications',
  ];

  Future<void> ensureUser({
    required String uid,
    required String email,
    required String fullName,
    String currencyCode = 'UGX',
    String? phoneNumber,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existingUser = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (existingUser.isEmpty) {
      await db.insert('users', {
        'id': uid,
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'preferred_currency': currencyCode,
        'theme_mode': 'system',
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'users',
        {
          'full_name': fullName,
          'email': email,
          'phone_number': phoneNumber,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [uid],
      );
    }
    await _ensureDefaultCategories(db, uid);
    final existing = await db.query(
      'accounts',
      where: 'user_id = ? AND is_archived = 0',
      whereArgs: [uid],
      limit: 1,
    );
    if (existing.isEmpty) {
      final account = FinancialAccount(
        id: _newId(),
        userId: uid,
        name: 'Cash Wallet',
        type: 'Cash',
        currencyCode: currencyCode,
        openingBalanceMinor: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await saveAccount(account);
    }
  }

  Future<FinanceSnapshot> loadSnapshot(String uid) async {
    final db = await _database.database;
    final accounts = await db.query(
      'accounts',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'is_archived, name COLLATE NOCASE',
    );
    final budgets = await db.query(
      'budgets',
      where: 'user_id = ? AND is_archived = 0',
      whereArgs: [uid],
      orderBy: 'start_date DESC',
    );
    final goals = await db.query(
      'savings_goals',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'target_date',
    );
    final contributions = await db.query(
      'savings_contributions',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'contribution_date DESC',
    );
    final debts = await db.query(
      'debts',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'due_date',
    );
    final debtPayments = await db.query(
      'debt_payments',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'payment_date DESC',
    );
    final recurring = await db.query(
      'recurring_transactions',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'next_occurrence',
    );
    final notifications = await db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'created_at DESC',
      limit: 100,
    );
    final categories = await db.query(
      'categories',
      where: 'user_id IS NULL OR user_id = ?',
      whereArgs: [uid],
      orderBy: 'type, name COLLATE NOCASE',
    );
    final recentTransactions = await db.query(
      'transactions',
      where: 'user_id = ? AND status = ?',
      whereArgs: [uid, 'active'],
      orderBy: 'transaction_date DESC, id DESC',
      limit: 4,
    );
    final accountBalances = await loadAccountBalances(uid);
    final historicalSummary = await loadSummary(uid: uid);
    final now = DateTime.now();
    final currentMonthSummary = await loadSummary(
      uid: uid,
      from: DateTime(now.year, now.month),
      through: now,
    );
    final monthlySummaries = await loadMonthlySummaries(
      uid: uid,
      monthCount: 12,
    );
    final budgetProgress = <String, BudgetProgress>{};
    for (final budget in budgets.map(FinancialBudget.fromMap)) {
      budgetProgress[budget.id] = await loadBudgetProgress(budget);
    }
    final balancesByCurrency = <String, int>{};
    for (final accountRow in accounts) {
      final account = FinancialAccount.fromMap(accountRow);
      if (account.isArchived) continue;
      balancesByCurrency.update(
        account.currencyCode,
        (value) => value + (accountBalances[account.id] ?? 0),
        ifAbsent: () => accountBalances[account.id] ?? 0,
      );
    }
    return FinanceSnapshot(
      accounts: accounts.map(FinancialAccount.fromMap).toList(),
      budgets: budgets.map(FinancialBudget.fromMap).toList(),
      goals: goals.map(SavingsGoal.fromMap).toList(),
      contributions: contributions.map(SavingsContribution.fromMap).toList(),
      debts: debts.map(DebtRecord.fromMap).toList(),
      debtPayments: debtPayments.map(DebtPayment.fromMap).toList(),
      recurringRules: recurring.map(RecurringRule.fromMap).toList(),
      notifications: notifications.map(AppNotification.fromMap).toList(),
      categories: categories,
      recentTransactions: recentTransactions
          .map(FinancialTransaction.fromMap)
          .toList(),
      summary: FinancialSummary(
        incomeByCurrency: historicalSummary.incomeByCurrency,
        expensesByCurrency: historicalSummary.expensesByCurrency,
        balanceByCurrency: balancesByCurrency,
      ),
      currentMonthSummary: currentMonthSummary,
      monthlySummaries: monthlySummaries,
      accountBalances: accountBalances,
      budgetProgress: budgetProgress,
    );
  }

  Future<TransactionPage> loadTransactionPage({
    required String uid,
    int pageSize = 50,
    int? beforeDate,
    String? beforeId,
    String? search,
    String? accountId,
    String? category,
    String? type,
    String? currencyCode,
    DateTime? from,
    DateTime? through,
    bool ascending = false,
  }) async {
    if (pageSize <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be greater than zero.');
    }

    final where = <String>['user_id = ?', 'status = ?'];
    final whereArgs = <Object?>[uid, 'active'];
    if (accountId != null) {
      where.add(
        "(account_id = ? OR (type = 'transfer' AND destination_account_id = ?))",
      );
      whereArgs.addAll([accountId, accountId]);
    }
    if (category != null) {
      where.add('category = ?');
      whereArgs.add(category);
    }
    if (type == 'expense') {
      where.add("type IN ('expense', 'refund')");
    } else if (type != null) {
      where.add('type = ?');
      whereArgs.add(type);
    }
    if (currencyCode != null) {
      where.add('currency_code = ?');
      whereArgs.add(currencyCode);
    }
    if (from != null) {
      where.add('transaction_date >= ?');
      whereArgs.add(from.millisecondsSinceEpoch);
    }
    if (through != null) {
      where.add('transaction_date <= ?');
      whereArgs.add(through.millisecondsSinceEpoch);
    }
    final normalizedSearch = search?.trim();
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      where.add(
        '(description LIKE ? OR category LIKE ? OR notes LIKE ?)',
      );
      final pattern = '%$normalizedSearch%';
      whereArgs.addAll([pattern, pattern, pattern]);
    }
    if (beforeDate != null && beforeId != null) {
      final operator = ascending ? '>' : '<';
      where.add(
        '(transaction_date $operator ? OR (transaction_date = ? AND id $operator ?))',
      );
      whereArgs.addAll([beforeDate, beforeDate, beforeId]);
    }

    final db = await _database.database;
    final rows = await db.query(
      'transactions',
      where: where.join(' AND '),
      whereArgs: whereArgs,
      orderBy:
          'transaction_date ${ascending ? 'ASC' : 'DESC'}, id ${ascending ? 'ASC' : 'DESC'}',
      limit: pageSize + 1,
    );
    final hasMore = rows.length > pageSize;
    return TransactionPage(
      transactions: rows
          .take(pageSize)
          .map(FinancialTransaction.fromMap)
          .toList(),
      hasMore: hasMore,
    );
  }

  Stream<FinancialTransaction> streamTransactions({
    required String uid,
    String? search,
    String? accountId,
    String? category,
    String? type,
    String? currencyCode,
    DateTime? from,
    DateTime? through,
  }) async* {
    int? beforeDate;
    String? beforeId;
    while (true) {
      final page = await loadTransactionPage(
        uid: uid,
        pageSize: 500,
        beforeDate: beforeDate,
        beforeId: beforeId,
        search: search,
        accountId: accountId,
        category: category,
        type: type,
        currencyCode: currencyCode,
        from: from,
        through: through,
      );
      for (final transaction in page.transactions) {
        yield transaction;
      }
      if (!page.hasMore || page.transactions.isEmpty) return;
      final last = page.transactions.last;
      beforeDate = last.occurredAt.millisecondsSinceEpoch;
      beforeId = last.id;
    }
  }

  Future<FinancialSummary> loadSummary({
    required String uid,
    DateTime? from,
    DateTime? through,
    String? search,
    String? accountId,
    String? category,
    String? type,
  }) async {
    final where = <String>['user_id = ?', 'status = ?'];
    final whereArgs = <Object?>[uid, 'active'];
    if (from != null) {
      where.add('transaction_date >= ?');
      whereArgs.add(from.millisecondsSinceEpoch);
    }
    if (through != null) {
      where.add('transaction_date <= ?');
      whereArgs.add(through.millisecondsSinceEpoch);
    }
    if (accountId != null) {
      where.add(
        "(account_id = ? OR (type = 'transfer' AND destination_account_id = ?))",
      );
      whereArgs.addAll([accountId, accountId]);
    }
    if (category != null) {
      where.add('category = ?');
      whereArgs.add(category);
    }
    if (type == 'expense') {
      where.add("type IN ('expense', 'refund')");
    } else if (type != null) {
      where.add('type = ?');
      whereArgs.add(type);
    }
    final normalizedSearch = search?.trim();
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      where.add(
        '(description LIKE ? OR category LIKE ? OR notes LIKE ?)',
      );
      final pattern = '%$normalizedSearch%';
      whereArgs.addAll([pattern, pattern, pattern]);
    }
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT currency_code,
        SUM(CASE WHEN type = 'income' THEN amount_minor ELSE 0 END) AS income_minor,
        SUM(CASE
          WHEN type = 'expense' THEN amount_minor
          WHEN type = 'refund' THEN -amount_minor
          ELSE 0
        END) AS expenses_minor
      FROM transactions
      WHERE ${where.join(' AND ')}
      GROUP BY currency_code
      ''',
      whereArgs,
    );
    final income = <String, int>{};
    final expenses = <String, int>{};
    for (final row in rows) {
      final currency = row['currency_code']! as String;
      income[currency] = row['income_minor']! as int;
      expenses[currency] = row['expenses_minor']! as int;
    }
    return FinancialSummary(
      incomeByCurrency: income,
      expensesByCurrency: expenses,
      balanceByCurrency: const {},
    );
  }

  Future<Map<String, FinancialSummary>> loadMonthlySummaries({
    required String uid,
    int monthCount = 6,
  }) async {
    if (monthCount <= 0) {
      throw ArgumentError.value(monthCount, 'monthCount', 'Must be greater than zero.');
    }
    final now = DateTime.now();
    final firstMonth = DateTime(now.year, now.month - monthCount + 1);
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT strftime(
          '%Y-%m',
          transaction_date / 1000,
          'unixepoch',
          'localtime'
        ) AS month,
        currency_code,
        SUM(CASE WHEN type = 'income' THEN amount_minor ELSE 0 END) AS income_minor,
        SUM(CASE
          WHEN type = 'expense' THEN amount_minor
          WHEN type = 'refund' THEN -amount_minor
          ELSE 0
        END) AS expenses_minor
      FROM transactions
      WHERE user_id = ? AND status = ?
        AND transaction_date >= ? AND transaction_date <= ?
      GROUP BY month, currency_code
      ''',
      [
        uid,
        'active',
        firstMonth.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      ],
    );
    final incomeByMonth = <String, Map<String, int>>{};
    final expensesByMonth = <String, Map<String, int>>{};
    for (final row in rows) {
      final month = row['month']! as String;
      final currency = row['currency_code']! as String;
      incomeByMonth.putIfAbsent(month, () => {})[currency] =
          row['income_minor']! as int;
      expensesByMonth.putIfAbsent(month, () => {})[currency] =
          row['expenses_minor']! as int;
    }
    return {
      for (var index = 0; index < monthCount; index++)
        _monthKey(DateTime(firstMonth.year, firstMonth.month + index)):
            FinancialSummary(
              incomeByCurrency:
                  incomeByMonth[_monthKey(
                    DateTime(firstMonth.year, firstMonth.month + index),
                  )] ??
                  const {},
              expensesByCurrency:
                  expensesByMonth[_monthKey(
                    DateTime(firstMonth.year, firstMonth.month + index),
                  )] ??
                  const {},
              balanceByCurrency: const {},
            ),
    };
  }

  Future<Map<String, int>> loadAccountBalances(String uid) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT a.id,
        a.opening_balance_minor
        + COALESCE((
          SELECT SUM(CASE
            WHEN t.type IN ('income', 'refund', 'adjustment') THEN t.amount_minor
            WHEN t.type IN ('expense', 'transfer') THEN -t.amount_minor
            ELSE 0
          END)
          FROM transactions t
          WHERE t.user_id = a.user_id
            AND t.account_id = a.id
            AND t.status = 'active'
        ), 0)
        + COALESCE((
          SELECT SUM(COALESCE(t.destination_amount_minor, t.amount_minor))
          FROM transactions t
          WHERE t.user_id = a.user_id
            AND t.destination_account_id = a.id
            AND t.type = 'transfer'
            AND t.status = 'active'
        ), 0) AS balance_minor
      FROM accounts a
      WHERE a.user_id = ?
      ''',
      [uid],
    );
    return {
      for (final row in rows)
        row['id']! as String: row['balance_minor']! as int,
    };
  }

  Future<int> _accountBalance(
    DatabaseExecutor db,
    FinancialAccount account, {
    String? excludedTransactionId,
  }) async {
    final excludedSource = excludedTransactionId == null
        ? ''
        : ' AND id != ?';
    final excludedDestination = excludedTransactionId == null
        ? ''
        : ' AND id != ?';
    final args = <Object?>[
      account.userId,
      account.id,
      if (excludedTransactionId != null) excludedTransactionId,
      account.userId,
      account.id,
      if (excludedTransactionId != null) excludedTransactionId,
    ];
    final rows = await db.rawQuery(
      '''
      SELECT ? +
        COALESCE((
          SELECT SUM(CASE
            WHEN type IN ('income', 'refund', 'adjustment') THEN amount_minor
            WHEN type IN ('expense', 'transfer') THEN -amount_minor
            ELSE 0
          END)
          FROM transactions
          WHERE user_id = ? AND account_id = ? AND status = 'active'$excludedSource
        ), 0)
        + COALESCE((
          SELECT SUM(COALESCE(destination_amount_minor, amount_minor))
          FROM transactions
          WHERE user_id = ? AND destination_account_id = ?
            AND type = 'transfer' AND status = 'active'$excludedDestination
        ), 0) AS balance_minor
      ''',
      [account.openingBalanceMinor, ...args],
    );
    return rows.first['balance_minor']! as int;
  }

  Future<BudgetProgress> loadBudgetProgress(
    FinancialBudget budget,
  ) async {
    final db = await _database.database;
    var categoryClause = '';
    if (budget.categoryIds.isNotEmpty) {
      categoryClause =
          ' AND category IN (${List.filled(budget.categoryIds.length, '?').join(', ')})';
    }
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE
        WHEN type = 'expense' THEN amount_minor
        WHEN type = 'refund' THEN -amount_minor
        ELSE 0
      END), 0) AS spent_minor
      FROM transactions
      WHERE user_id = ? AND status = ? AND currency_code = ?
        AND transaction_date >= ? AND transaction_date <= ?
        AND type IN ('expense', 'refund')$categoryClause
      ''',
      [
        budget.userId,
        'active',
        budget.currencyCode,
        budget.startDate.millisecondsSinceEpoch,
        budget.endDate.millisecondsSinceEpoch,
        ...budget.categoryIds,
      ],
    );
    var spent = rows.first['spent_minor']! as int;
    if (spent < 0) spent = 0;
    final usage = budget.limitMinor <= 0
        ? 0
        : spent * 100 ~/ budget.limitMinor;
    return BudgetProgress(
      spentMinor: spent,
      remainingMinor: budget.limitMinor - spent,
      usagePercent: usage,
    );
  }

  Future<List<CategorySpending>> loadCategorySpending({
    required String uid,
    required String currencyCode,
    DateTime? from,
    DateTime? through,
  }) async {
    final where = <String>[
      'user_id = ?',
      'status = ?',
      'currency_code = ?',
      "type IN ('expense', 'refund')",
    ];
    final args = <Object?>[uid, 'active', currencyCode];
    if (from != null) {
      where.add('transaction_date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (through != null) {
      where.add('transaction_date <= ?');
      args.add(through.millisecondsSinceEpoch);
    }
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT category, SUM(CASE
        WHEN type = 'expense' THEN amount_minor
        WHEN type = 'refund' THEN -amount_minor
        ELSE 0
      END) AS amount_minor
      FROM transactions
      WHERE ${where.join(' AND ')}
      GROUP BY category
      HAVING amount_minor > 0
      ORDER BY amount_minor DESC
      ''',
      args,
    );
    return [
      for (final row in rows)
        CategorySpending(
          category: row['category']! as String,
          currencyCode: currencyCode,
          amountMinor: row['amount_minor']! as int,
        ),
    ];
  }

  Future<void> saveAccount(FinancialAccount account) async {
    _requireName(account.name, 'Account name');
    if (account.openingBalanceMinor < 0 && !account.allowOverdraft) {
      throw const FinanceException('Opening balance cannot be negative.');
    }
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'accounts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [account.id, account.userId],
      limit: 1,
    );
    final map = account.toMap()
      ..['created_at'] =
          account.createdAt?.millisecondsSinceEpoch ??
          (existing.isEmpty ? now : existing.first['created_at'])
      ..['updated_at'] = now
      ..['version'] =
          ((existing.isEmpty ? 0 : existing.first['version'] as int) + 1);
    await db.transaction((transaction) async {
      await _upsert(transaction, 'accounts', map);
      await _queue(transaction, account.userId, 'accounts', account.id);
    });
  }

  Future<void> archiveAccount(String uid, String accountId) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      final result = await transaction.update(
        'accounts',
        {
          'is_archived': 1,
          'sync_status': SyncStatus.pending.name,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [accountId, uid],
      );
      if (result > 0) await _queue(transaction, uid, 'accounts', accountId);
    });
  }

  Future<void> saveTransaction(
    FinancialTransaction entry, {
    List<ReceiptAttachment> receipts = const [],
  }) async {
    if (entry.amountMinor <= 0) {
      throw const FinanceException('Amount must be greater than zero.');
    }
    _requireName(entry.description, 'Description');
    final db = await _database.database;
    final accounts = await db.query(
      'accounts',
      where: 'user_id = ?',
      whereArgs: [entry.userId],
    );
    final accountById = {
      for (final row in accounts)
        row['id']! as String: FinancialAccount.fromMap(row),
    };
    final account = accountById[entry.accountId];
    if (account == null || account.isArchived) {
      throw const FinanceException('Select an active account you own.');
    }
    if (account.currencyCode != entry.currencyCode) {
      throw const FinanceException(
        'Transaction currency must match the selected account currency.',
      );
    }
    if (entry.type == TransactionType.transfer) {
      final destination = accountById[entry.destinationAccountId];
      if (destination == null ||
          destination.isArchived ||
          destination.id == account.id) {
        throw const FinanceException(
          'Select a different active destination account.',
        );
      }
      if (destination.currencyCode != entry.destinationCurrencyCode) {
        throw const FinanceException(
          'Destination currency does not match the account.',
        );
      }
      if (destination.currencyCode != account.currencyCode &&
          (entry.exchangeRate == null ||
              entry.exchangeRate!.trim().isEmpty ||
              (entry.destinationAmountMinor ?? 0) <= 0)) {
        throw const FinanceException(
          'Transfers between currencies need an exchange rate and destination amount.',
        );
      }
      if (destination.currencyCode == account.currencyCode &&
          entry.destinationAmountMinor != null &&
          entry.destinationAmountMinor != entry.amountMinor) {
        throw const FinanceException(
          'Same-currency transfers must use the same source and destination amount.',
        );
      }
    }

    if (!account.allowOverdraft &&
        (entry.type == TransactionType.expense ||
            entry.type == TransactionType.transfer)) {
      final available = await _accountBalance(
        db,
        account,
        excludedTransactionId: entry.id,
      );
      if (entry.amountMinor > available) {
        throw const FinanceException(
          'This transaction exceeds the available account balance. Enable overdraft for this account if appropriate.',
        );
      }
    }

    final now = DateTime.now();
    final existing = await db.query(
      'transactions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [entry.id, entry.userId],
      limit: 1,
    );
    final map = entry.toMap()
      ..['created_at'] =
          entry.createdAt?.millisecondsSinceEpoch ??
          (existing.isEmpty
              ? now.millisecondsSinceEpoch
              : existing.first['created_at'])
      ..['updated_at'] = now.millisecondsSinceEpoch
      ..['sync_status'] = SyncStatus.pending.name
      ..['version'] =
          ((existing.isEmpty ? 0 : existing.first['version'] as int) + 1)
      ..remove('deleted_at');
    await db.transaction((transaction) async {
      await _upsert(transaction, 'transactions', map);
      await transaction.delete(
        'receipts',
        where: 'user_id = ? AND transaction_id = ?',
        whereArgs: [entry.userId, entry.id],
      );
      for (final receipt in receipts) {
        if (receipt.userId != entry.userId ||
            receipt.transactionId != entry.id) {
          throw const FinanceException(
            'Receipt attachment does not belong to this transaction.',
          );
        }
        await transaction.insert('receipts', receipt.toMap());
      }
      await _queue(transaction, entry.userId, 'transactions', entry.id);
    });
  }

  Future<List<ReceiptAttachment>> loadTransactionReceipts(
    String uid,
    String transactionId,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'receipts',
      where: 'user_id = ? AND transaction_id = ?',
      whereArgs: [uid, transactionId],
      orderBy: 'created_at, id',
    );
    return rows.map(ReceiptAttachment.fromMap).toList();
  }

  Future<void> voidTransaction(String uid, String id) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      final result = await transaction.update(
        'transactions',
        {
          'status': 'voided',
          'sync_status': SyncStatus.pending.name,
          'deleted_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND user_id = ? AND status = ?',
        whereArgs: [id, uid, 'active'],
      );
      if (result > 0) await _queue(transaction, uid, 'transactions', id);
    });
  }

  Future<void> saveBudget(FinancialBudget budget) async {
    _requireName(budget.name, 'Budget name');
    if (budget.limitMinor <= 0) {
      throw const FinanceException('Budget limit must be greater than zero.');
    }
    if (budget.endDate.isBefore(budget.startDate)) {
      throw const FinanceException(
        'End date must be on or after the start date.',
      );
    }
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'budgets',
      where: 'id = ? AND user_id = ?',
      whereArgs: [budget.id, budget.userId],
      limit: 1,
    );
    final map = budget.toMap()
      ..['created_at'] =
          budget.createdAt?.millisecondsSinceEpoch ??
          (existing.isEmpty ? now : existing.first['created_at'])
      ..['updated_at'] = now
      ..['sync_status'] = SyncStatus.pending.name
      ..['version'] =
          ((existing.isEmpty ? 0 : existing.first['version'] as int) + 1);
    await db.transaction((transaction) async {
      await _upsert(transaction, 'budgets', map);
      await _queue(transaction, budget.userId, 'budgets', budget.id);
    });
  }

  Future<void> archiveBudget(String uid, String id) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      final result = await transaction.update(
        'budgets',
        {
          'is_archived': 1,
          'sync_status': SyncStatus.pending.name,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, uid],
      );
      if (result > 0) await _queue(transaction, uid, 'budgets', id);
    });
  }

  Future<void> saveGoal(SavingsGoal goal) async {
    _requireName(goal.name, 'Goal name');
    if (goal.targetMinor <= 0) {
      throw const FinanceException('Goal amount must be greater than zero.');
    }
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'savings_goals',
      where: 'id = ? AND user_id = ?',
      whereArgs: [goal.id, goal.userId],
      limit: 1,
    );
    final map = goal.toMap()
      ..['created_at'] =
          goal.createdAt?.millisecondsSinceEpoch ??
          (existing.isEmpty ? now : existing.first['created_at'])
      ..['updated_at'] = now
      ..['sync_status'] = SyncStatus.pending.name
      ..['version'] =
          ((existing.isEmpty ? 0 : existing.first['version'] as int) + 1);
    await db.transaction((transaction) async {
      await _upsert(transaction, 'savings_goals', map);
      await _queue(transaction, goal.userId, 'savings_goals', goal.id);
    });
  }

  Future<void> saveContribution(SavingsContribution contribution) async {
    if (contribution.amountMinor <= 0) {
      throw const FinanceException('Contribution must be greater than zero.');
    }
    final db = await _database.database;
    final goalRows = await db.query(
      'savings_goals',
      where: 'id = ? AND user_id = ?',
      whereArgs: [contribution.goalId, contribution.userId],
      limit: 1,
    );
    if (goalRows.isEmpty) {
      throw const FinanceException('Savings goal was not found.');
    }
    final goal = SavingsGoal.fromMap(goalRows.first);
    if (goal.currencyCode != contribution.currencyCode) {
      throw const FinanceException(
        'Contribution currency must match the goal currency.',
      );
    }
    final existingRows = await db.query(
      'savings_contributions',
      where: 'goal_id = ? AND user_id = ?',
      whereArgs: [contribution.goalId, contribution.userId],
    );
    final existing = existingRows.map(SavingsContribution.fromMap).toList();
    if (contribution.type == 'withdrawal' &&
        contribution.amountMinor >
            _calculations.savingsTotal(contribution.goalId, existing)) {
      throw const FinanceException(
        'Withdrawal exceeds the amount saved toward this goal.',
      );
    }
    final map = contribution.toMap()
      ..['created_at'] = DateTime.now().millisecondsSinceEpoch
      ..['sync_status'] = SyncStatus.pending.name;
    await db.transaction((transaction) async {
      await transaction.insert(
        'savings_contributions',
        map,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await _queue(
        transaction,
        contribution.userId,
        'savings_contributions',
        contribution.id,
      );
    });
  }

  Future<void> archiveGoal(String uid, String id) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      final result = await transaction.update(
        'savings_goals',
        {
          'status': 'paused',
          'sync_status': SyncStatus.pending.name,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, uid],
      );
      if (result > 0) await _queue(transaction, uid, 'savings_goals', id);
    });
  }

  Future<void> saveDebt(DebtRecord debt) async {
    _requireName(debt.personName, 'Person or institution');
    if (debt.principalMinor <= 0) {
      throw const FinanceException('Debt amount must be greater than zero.');
    }
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'debts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [debt.id, debt.userId],
      limit: 1,
    );
    final map = debt.toMap()
      ..['created_at'] =
          debt.createdAt?.millisecondsSinceEpoch ??
          (existing.isEmpty ? now : existing.first['created_at'])
      ..['updated_at'] = now
      ..['sync_status'] = SyncStatus.pending.name
      ..['version'] =
          ((existing.isEmpty ? 0 : existing.first['version'] as int) + 1);
    await db.transaction((transaction) async {
      await _upsert(transaction, 'debts', map);
      await _queue(transaction, debt.userId, 'debts', debt.id);
    });
  }

  Future<void> saveDebtPayment({
    required String uid,
    required String debtId,
    required String paymentId,
    required int amountMinor,
    required String paymentType,
    required DateTime date,
    String? accountId,
    String notes = '',
  }) async {
    if (amountMinor <= 0) {
      throw const FinanceException('Payment must be greater than zero.');
    }
    final db = await _database.database;
    final debtRows = await db.query(
      'debts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [debtId, uid],
      limit: 1,
    );
    if (debtRows.isEmpty) {
      throw const FinanceException('Debt record was not found.');
    }
    final debt = DebtRecord.fromMap(debtRows.first);
    final paymentRows = await db.query(
      'debt_payments',
      where: 'debt_id = ? AND user_id = ?',
      whereArgs: [debtId, uid],
    );
    final paid = paymentRows.fold<int>(
      0,
      (total, row) => total + (row['amount_minor']! as int),
    );
    if (amountMinor > debt.principalMinor - paid) {
      throw const FinanceException(
        'Payment exceeds the outstanding principal.',
      );
    }
    FinancialAccount? account;
    if (accountId != null) {
      final accountRows = await db.query(
        'accounts',
        where: 'id = ? AND user_id = ? AND is_archived = 0',
        whereArgs: [accountId, uid],
        limit: 1,
      );
      if (accountRows.isEmpty) {
        throw const FinanceException('Select an active account you own.');
      }
      account = FinancialAccount.fromMap(accountRows.first);
      if (account.currencyCode != debt.currencyCode) {
        throw const FinanceException(
          'Payment account currency must match the debt currency.',
        );
      }
      if (debt.type == 'borrowed' && !account.allowOverdraft) {
        if (amountMinor > await _accountBalance(db, account)) {
          throw const FinanceException(
            'Payment exceeds the available account balance.',
          );
        }
      }
    }
    await db.transaction((transaction) async {
      await transaction.insert('debt_payments', {
        'id': paymentId,
        'user_id': uid,
        'debt_id': debtId,
        'amount_minor': amountMinor,
        'payment_type': paymentType,
        'account_id': accountId,
        'payment_date': date.millisecondsSinceEpoch,
        'notes': notes,
        'sync_status': SyncStatus.pending.name,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      final remaining = debt.principalMinor - paid - amountMinor;
      await transaction.update(
        'debts',
        {
          'status': remaining == 0 ? 'settled' : 'active',
          'sync_status': SyncStatus.pending.name,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [debtId, uid],
      );
      await _queue(transaction, uid, 'debt_payments', paymentId);
      await _queue(transaction, uid, 'debts', debtId);
      if (account != null) {
        final expense = debt.type == 'borrowed';
        final entryId = 'debt_payment_$paymentId';
        final timestamp = date.millisecondsSinceEpoch;
        await transaction.insert('transactions', {
          'id': entryId,
          'user_id': uid,
          'account_id': accountId,
          'type': expense
              ? TransactionType.expense.name
              : TransactionType.income.name,
          'amount_minor': amountMinor,
          'currency_code': debt.currencyCode,
          'category': expense ? 'Debt repayment' : 'Debt collection',
          'description': expense
              ? 'Repayment to ${debt.personName}'
              : 'Payment from ${debt.personName}',
          'transaction_date': timestamp,
          'destination_account_id': null,
          'destination_amount_minor': null,
          'destination_currency_code': null,
          'exchange_rate': null,
          'payment_method': 'Other',
          'notes': notes,
          'receipt_path': null,
          'recurring_id': null,
          'transfer_id': null,
          'status': 'active',
          'sync_status': SyncStatus.pending.name,
          'version': 1,
          'created_at': timestamp,
          'updated_at': timestamp,
          'deleted_at': null,
        }, conflictAlgorithm: ConflictAlgorithm.abort);
        await _queue(transaction, uid, 'transactions', entryId);
      }
    });
  }

  Future<void> saveRecurringRule(RecurringRule rule) async {
    if (rule.amountMinor <= 0) {
      throw const FinanceException(
        'Recurring amount must be greater than zero.',
      );
    }
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'recurring_transactions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [rule.id, rule.userId],
      limit: 1,
    );
    final map = rule.toMap()
      ..['created_at'] =
          rule.createdAt?.millisecondsSinceEpoch ??
          (existing.isEmpty ? now : existing.first['created_at'])
      ..['updated_at'] = now;
    await db.transaction((transaction) async {
      await _upsert(transaction, 'recurring_transactions', map);
      await _queue(transaction, rule.userId, 'recurring_transactions', rule.id);
    });
  }

  Future<int> processDueRecurring(String uid) async {
    final db = await _database.database;
    final now = DateTime.now();
    final rows = await db.query(
      'recurring_transactions',
      where: 'user_id = ? AND is_active = 1 AND next_occurrence <= ?',
      whereArgs: [uid, now.millisecondsSinceEpoch],
    );
    var processed = 0;
    for (final row in rows) {
      var rule = RecurringRule.fromMap(row);
      while (!rule.nextOccurrence.isAfter(now) &&
          (rule.endDate == null ||
              !rule.nextOccurrence.isAfter(rule.endDate!))) {
        final occurrenceId =
            '${rule.id}_${rule.nextOccurrence.millisecondsSinceEpoch}';
        final exists = await db.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [occurrenceId],
          limit: 1,
        );
        if (exists.isEmpty) {
          await saveTransaction(
            FinancialTransaction(
              id: occurrenceId,
              userId: uid,
              accountId: rule.accountId,
              type: TransactionType.values.byName(rule.type),
              amountMinor: rule.amountMinor,
              currencyCode: rule.currencyCode,
              category: rule.category,
              description: rule.description,
              occurredAt: rule.nextOccurrence,
              recurringId: rule.id,
              createdAt: now,
              updatedAt: now,
            ),
          );
          processed++;
        }
        final next = _nextOccurrence(rule.nextOccurrence, rule.frequency);
        rule = RecurringRule(
          id: rule.id,
          userId: rule.userId,
          accountId: rule.accountId,
          type: rule.type,
          amountMinor: rule.amountMinor,
          currencyCode: rule.currencyCode,
          category: rule.category,
          description: rule.description,
          frequency: rule.frequency,
          nextOccurrence: next,
          endDate: rule.endDate,
          isActive: rule.endDate == null || !next.isAfter(rule.endDate!),
          createdAt: rule.createdAt,
          updatedAt: now,
          syncStatus: SyncStatus.pending,
        );
      }
      await saveRecurringRule(rule);
    }
    return processed;
  }

  Future<void> saveCategory({
    required String uid,
    required String id,
    required String name,
    required String type,
    String icon = 'category',
    String color = '#31C99A',
  }) async {
    _requireName(name, 'Category name');
    final db = await _database.database;
    await db.transaction((transaction) async {
      await _upsert(transaction, 'categories', {
        'id': id,
        'user_id': uid,
        'name': name.trim(),
        'type': type,
        'icon': icon,
        'color': color,
        'is_default': 0,
        'is_active': 1,
        'sync_status': SyncStatus.pending.name,
      });
      await _queue(transaction, uid, 'categories', id);
    });
  }

  Future<void> archiveCategory(String uid, String id) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      final result = await transaction.update(
        'categories',
        {'is_active': 0, 'sync_status': SyncStatus.pending.name},
        where: 'id = ? AND user_id = ? AND is_default = 0',
        whereArgs: [id, uid],
      );
      if (result > 0) await _queue(transaction, uid, 'categories', id);
    });
  }

  Future<void> saveNotification(AppNotification notification) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      final inserted = await transaction.insert(
        'notifications',
        notification.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (inserted > 0) {
        await _queue(
          transaction,
          notification.userId,
          'notifications',
          notification.id,
        );
      }
    });
  }

  Future<void> markNotificationRead(String uid, String id) async {
    final db = await _database.database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, uid],
    );
  }

  Future<void> markAllNotificationsRead(String uid) async {
    final db = await _database.database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'user_id = ?',
      whereArgs: [uid],
    );
  }

  Future<void> deleteNotification(String uid, String id) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      await transaction.delete(
        'notifications',
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, uid],
      );
      await transaction.insert('sync_queue', {
        'user_id': uid,
        'collection_name': 'notifications',
        'record_id': id,
        'operation': 'delete',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, Object?>>> pendingSync(String uid) async {
    final db = await _database.database;
    return db.query(
      'sync_queue',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'created_at',
      limit: 100,
    );
  }

  Future<Map<String, Object?>?> recordForSync(
    String collection,
    String id,
    String uid,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      collection,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, uid],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markSynced(String uid, String collection, String id) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      if (collection != 'notifications') {
        await transaction.update(
          collection,
          {'sync_status': SyncStatus.synced.name},
          where: 'id = ? AND user_id = ?',
          whereArgs: [id, uid],
        );
      }
      await transaction.delete(
        'sync_queue',
        where: 'user_id = ? AND collection_name = ? AND record_id = ?',
        whereArgs: [uid, collection, id],
      );
    });
  }

  Future<void> markSyncFailed(int queueId, String message) async {
    final db = await _database.database;
    await db.rawUpdate(
      'UPDATE sync_queue SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [message, queueId],
    );
  }

  Future<void> markSyncConflict({
    required String uid,
    required String collection,
    required String recordId,
    required Map<String, Object?> localRecord,
    required Map<String, Object?> remoteRecord,
  }) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      await transaction.insert('sync_conflicts', {
        'id': '${collection}_$recordId',
        'user_id': uid,
        'collection_name': collection,
        'record_id': recordId,
        'local_record': jsonEncode(localRecord),
        'remote_record': jsonEncode(remoteRecord),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.update(
        collection,
        {'sync_status': SyncStatus.conflict.name},
        where: 'id = ? AND user_id = ?',
        whereArgs: [recordId, uid],
      );
      await transaction.delete(
        'sync_queue',
        where: 'user_id = ? AND collection_name = ? AND record_id = ?',
        whereArgs: [uid, collection, recordId],
      );
    });
  }

  Future<List<Map<String, Object?>>> syncConflicts(String uid) async {
    final db = await _database.database;
    return db.query(
      'sync_conflicts',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> resolveSyncConflict({
    required String uid,
    required String collection,
    required String recordId,
    required bool keepLocal,
  }) async {
    final db = await _database.database;
    final conflicts = await db.query(
      'sync_conflicts',
      where: 'user_id = ? AND collection_name = ? AND record_id = ?',
      whereArgs: [uid, collection, recordId],
      limit: 1,
    );
    if (conflicts.isEmpty) return;
    final conflict = conflicts.first;
    if (keepLocal) {
      final local = await recordForSync(collection, recordId, uid);
      if (local == null) {
        throw const FinanceException(
          'The local version of this record is missing.',
        );
      }
      await db.transaction((transaction) async {
        await transaction.update(
          collection,
          {
            'version': ((local['version'] as int?) ?? 0) + 1,
            'sync_status': SyncStatus.pending.name,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [recordId, uid],
        );
        await _queue(transaction, uid, collection, recordId);
        await transaction.delete(
          'sync_conflicts',
          where: 'id = ?',
          whereArgs: [conflict['id']],
        );
      });
    } else {
      final remote = jsonDecode(conflict['remote_record']! as String);
      if (remote is Map<String, dynamic>) {
        await applyRemoteRecord(
          uid,
          collection,
          remote.cast<String, Object?>(),
        );
      }
      await db.delete(
        'sync_conflicts',
        where: 'id = ? AND user_id = ?',
        whereArgs: [conflict['id'], uid],
      );
    }
  }

  Future<void> applyRemoteRecord(
    String uid,
    String collection,
    Map<String, Object?> data,
  ) async {
    final db = await _database.database;
    final id = data['id'];
    if (id is! String || data['user_id'] != uid) return;
    final pending = await db.query(
      'sync_queue',
      where: 'user_id = ? AND collection_name = ? AND record_id = ?',
      whereArgs: [uid, collection, id],
      limit: 1,
    );
    if (pending.isNotEmpty) return;
    final table = _collectionTable[collection];
    if (table == null) return;
    final row = Map<String, Object?>.from(data)
      ..['sync_status'] = SyncStatus.synced.name;
    await _upsert(db, table, row);
  }

  Future<void> setPreferredCurrency(String uid, String currency) async {
    final db = await _database.database;
    await db.update(
      'users',
      {
        'preferred_currency': currency,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [uid],
    );
  }

  Future<String> preferredCurrency(String uid) async {
    final db = await _database.database;
    final rows = await db.query(
      'users',
      columns: ['preferred_currency'],
      where: 'id = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return rows.isEmpty ? 'UGX' : rows.first['preferred_currency']! as String;
  }

  Future<void> writeBackupRecord({
    required String uid,
    required String id,
    required String localPath,
    required bool verified,
  }) async {
    final db = await _database.database;
    await db.insert('backup_records', {
      'id': id,
      'user_id': uid,
      'local_path': localPath,
      'version': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'verified': verified ? 1 : 0,
      'status': verified ? 'verified' : 'failed',
    });
  }

  Future<void> _ensureDefaultCategories(DatabaseExecutor db, String uid) async {
    const defaults = [
      ('salary', 'Salary', 'income'),
      ('business', 'Business', 'income'),
      ('allowance', 'Allowance', 'income'),
      ('scholarship', 'Scholarship', 'income'),
      ('freelance', 'Freelance', 'income'),
      ('gift', 'Gift', 'income'),
      ('other_income', 'Other income', 'income'),
      ('food', 'Food', 'expense'),
      ('accommodation', 'Accommodation', 'expense'),
      ('transport', 'Transport', 'expense'),
      ('education', 'Education', 'expense'),
      ('communication', 'Communication', 'expense'),
      ('shopping', 'Shopping', 'expense'),
      ('personal_care', 'Personal care', 'expense'),
      ('entertainment', 'Entertainment', 'expense'),
      ('health', 'Health', 'expense'),
      ('bills', 'Bills', 'expense'),
      ('other', 'Other', 'expense'),
    ];
    for (final (id, name, type) in defaults) {
      await db.insert('categories', {
        'id': '${uid}_$id',
        'user_id': uid,
        'name': name,
        'type': type,
        'icon': 'category',
        'color': '#31C99A',
        'is_default': 1,
        'is_active': 1,
        'sync_status': SyncStatus.synced.name,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _queue(
    DatabaseExecutor db,
    String uid,
    String collection,
    String id,
  ) async {
    await db.insert('sync_queue', {
      'user_id': uid,
      'collection_name': collection,
      'record_id': id,
      'operation': 'upsert',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _upsert(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> values,
  ) async {
    final id = values['id'];
    final userId = values['user_id'];
    final where = userId == null ? 'id = ?' : 'id = ? AND user_id = ?';
    final whereArgs = userId == null ? [id] : [id, userId];
    final updated = await db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
    );
    if (updated == 0) {
      await db.insert(
        table,
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  static void _requireName(String value, String label) {
    if (value.trim().isEmpty) throw FinanceException('$label is required.');
    if (value.trim().length > 100) {
      throw FinanceException('$label must be 100 characters or fewer.');
    }
  }

  static String createId() => _newId();

  static String _newId() {
    final random = Random.secure();
    final suffix = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }

  static DateTime _nextOccurrence(DateTime current, String frequency) {
    return switch (frequency) {
      'daily' => current.add(const Duration(days: 1)),
      'weekly' => current.add(const Duration(days: 7)),
      'yearly' => DateTime(current.year + 1, current.month, current.day),
      _ => _addMonth(current),
    };
  }

  static DateTime _addMonth(DateTime current) {
    final nextMonth = DateTime(current.year, current.month + 1);
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    return DateTime(
      nextMonth.year,
      nextMonth.month,
      min(current.day, lastDay),
      current.hour,
      current.minute,
      current.second,
    );
  }

  static const _collectionTable = <String, String>{
    'accounts': 'accounts',
    'transactions': 'transactions',
    'budgets': 'budgets',
    'savings_goals': 'savings_goals',
    'savings_contributions': 'savings_contributions',
    'debts': 'debts',
    'debt_payments': 'debt_payments',
    'recurring_transactions': 'recurring_transactions',
    'categories': 'categories',
    'notifications': 'notifications',
    'receipts': 'receipts',
    'backup_records': 'backup_records',
  };
}
