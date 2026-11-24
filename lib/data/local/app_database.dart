import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _transactionIndexes = [
    'CREATE INDEX transactions_user_status_date_idx ON transactions(user_id, status, transaction_date DESC, id DESC)',
    'CREATE INDEX transactions_account_status_date_idx ON transactions(user_id, account_id, status, transaction_date DESC, id DESC)',
    'CREATE INDEX transactions_type_date_idx ON transactions(user_id, status, type, transaction_date DESC, id DESC)',
    'CREATE INDEX transactions_category_date_idx ON transactions(user_id, status, category, transaction_date DESC, id DESC)',
    'CREATE INDEX transactions_destination_idx ON transactions(user_id, destination_account_id, status, transaction_date DESC)',
  ];
  static const _receiptIndexes = [
    'CREATE INDEX receipts_transaction_idx ON receipts(user_id, transaction_id, created_at)',
  ];
  static const _syncQueueIndexes = [
    'CREATE INDEX sync_queue_user_id_idx ON sync_queue(user_id, id)',
  ];

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;
    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      '$databasePath/moneywise.db',
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    return _database!;
  }

  Future<void> close() async {
    final db = _database;
    if (db == null || !db.isOpen) return;
    await db.close();
    _database = null;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone_number TEXT,
        preferred_currency TEXT NOT NULL DEFAULT 'UGX',
        theme_mode TEXT NOT NULL DEFAULT 'system',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        account_type TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        opening_balance_minor INTEGER NOT NULL DEFAULT 0,
        allow_overdraft INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        version INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX accounts_user_idx ON accounts(user_id, is_archived)',
    );
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        currency_code TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        transaction_date INTEGER NOT NULL,
        destination_account_id TEXT,
        destination_amount_minor INTEGER,
        destination_currency_code TEXT,
        exchange_rate TEXT,
        payment_method TEXT NOT NULL DEFAULT 'Cash',
        notes TEXT NOT NULL DEFAULT '',
        receipt_path TEXT,
        recurring_id TEXT,
        transfer_id TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        version INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX transactions_user_date_idx ON transactions(user_id, transaction_date DESC)',
    );
    await db.execute(
      'CREATE INDEX transactions_account_date_idx ON transactions(account_id, transaction_date DESC)',
    );
    await _createTransactionIndexes(db);
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        limit_minor INTEGER NOT NULL,
        currency_code TEXT NOT NULL,
        start_date INTEGER NOT NULL,
        end_date INTEGER NOT NULL,
        category_ids TEXT NOT NULL DEFAULT '',
        alert_percentage INTEGER NOT NULL DEFAULT 70,
        is_archived INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        version INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX budgets_user_idx ON budgets(user_id, is_archived)',
    );
    await db.execute('''
      CREATE TABLE savings_goals (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        target_minor INTEGER NOT NULL,
        currency_code TEXT NOT NULL,
        target_date INTEGER NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'active',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        version INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE savings_contributions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        goal_id TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        currency_code TEXT NOT NULL,
        type TEXT NOT NULL,
        contribution_date INTEGER NOT NULL,
        account_id TEXT,
        notes TEXT NOT NULL DEFAULT '',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(goal_id) REFERENCES savings_goals(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        person_name TEXT NOT NULL,
        debt_type TEXT NOT NULL,
        principal_minor INTEGER NOT NULL,
        currency_code TEXT NOT NULL,
        due_date INTEGER,
        notes TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'active',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        version INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE debt_payments (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        debt_id TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        payment_type TEXT NOT NULL,
        account_id TEXT,
        payment_date INTEGER NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(debt_id) REFERENCES debts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        currency_code TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        frequency TEXT NOT NULL,
        next_occurrence INTEGER NOT NULL,
        end_date INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        last_occurrence_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'category',
        color TEXT NOT NULL DEFAULT '#31C99A',
        is_default INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        UNIQUE(user_id, name, type)
      )
    ''');
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        related_id TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX notifications_user_date_idx ON notifications(user_id, created_at DESC)',
    );
    await db.execute('''
      CREATE TABLE receipts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        transaction_id TEXT NOT NULL,
        local_path TEXT NOT NULL,
        cloud_path TEXT,
        mime_type TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        upload_status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )
    ''');
    await _createReceiptIndexes(db);
    await db.execute('''
      CREATE TABLE backup_records (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        local_path TEXT,
        cloud_path TEXT,
        version INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        verified INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        collection_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL DEFAULT 'upsert',
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at INTEGER NOT NULL,
        UNIQUE(user_id, collection_name, record_id)
      )
    ''');
    await _createSyncQueueIndexes(db);
    await db.execute('''
      CREATE TABLE sync_conflicts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        collection_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        local_record TEXT NOT NULL,
        remote_record TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(user_id, collection_name, record_id)
      )
    ''');
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createTransactionIndexes(db);
      await _createReceiptIndexes(db);
      await _createSyncQueueIndexes(db);
    }
  }

  Future<void> _createTransactionIndexes(DatabaseExecutor db) async {
    for (final statement in _transactionIndexes) {
      await db.execute(statement);
    }
  }

  Future<void> _createReceiptIndexes(DatabaseExecutor db) async {
    for (final statement in _receiptIndexes) {
      await db.execute(statement);
    }
  }

  Future<void> _createSyncQueueIndexes(DatabaseExecutor db) async {
    for (final statement in _syncQueueIndexes) {
      await db.execute(statement);
    }
  }
}
