import 'package:flutter/foundation.dart';

enum TransactionType { income, expense, transfer, refund, adjustment }

enum SyncStatus { pending, synced, conflict, failed }

class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.openingBalanceMinor,
    this.allowOverdraft = false,
    this.isArchived = false,
    this.syncStatus = SyncStatus.pending,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String type;
  final String currencyCode;
  final int openingBalanceMinor;
  final bool allowOverdraft;
  final bool isArchived;
  final SyncStatus syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FinancialAccount.fromMap(Map<String, Object?> map) {
    return FinancialAccount(
      id: map['id']! as String,
      userId: map['user_id']! as String,
      name: map['name']! as String,
      type: map['account_type']! as String,
      currencyCode: map['currency_code']! as String,
      openingBalanceMinor: map['opening_balance_minor']! as int,
      allowOverdraft: (map['allow_overdraft'] as int? ?? 0) == 1,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      syncStatus: _syncStatus(map['sync_status']),
      createdAt: _dateTime(map['created_at']),
      updatedAt: _dateTime(map['updated_at']),
    );
  }

  Map<String, Object?> toMap({bool includeSync = true}) => {
    'id': id,
    'user_id': userId,
    'name': name,
    'account_type': type,
    'currency_code': currencyCode,
    'opening_balance_minor': openingBalanceMinor,
    'allow_overdraft': allowOverdraft ? 1 : 0,
    'is_archived': isArchived ? 1 : 0,
    if (includeSync) 'sync_status': syncStatus.name,
    'created_at': createdAt?.millisecondsSinceEpoch,
    'updated_at': updatedAt?.millisecondsSinceEpoch,
  };

  Map<String, Object?> toCloudMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'type': type,
    'currencyCode': currencyCode,
    'openingBalanceMinor': openingBalanceMinor,
    'allowOverdraft': allowOverdraft,
    'isArchived': isArchived,
    'createdAt': createdAt?.millisecondsSinceEpoch,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
  };
}

class ReceiptAttachment {
  const ReceiptAttachment({
    required this.id,
    required this.userId,
    required this.transactionId,
    required this.localPath,
    required this.mimeType,
    required this.fileSize,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String transactionId;
  final String localPath;
  final String mimeType;
  final int fileSize;
  final DateTime createdAt;

  factory ReceiptAttachment.fromMap(Map<String, Object?> map) {
    return ReceiptAttachment(
      id: map['id']! as String,
      userId: map['user_id']! as String,
      transactionId: map['transaction_id']! as String,
      localPath: map['local_path']! as String,
      mimeType: map['mime_type']! as String,
      fileSize: map['file_size']! as int,
      createdAt: _dateTime(map['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'transaction_id': transactionId,
    'local_path': localPath,
    'cloud_path': null,
    'mime_type': mimeType,
    'file_size': fileSize,
    'upload_status': 'pending',
    'created_at': createdAt.millisecondsSinceEpoch,
  };
}

class FinancialTransaction {
  const FinancialTransaction({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.type,
    required this.amountMinor,
    required this.currencyCode,
    required this.category,
    required this.description,
    required this.occurredAt,
    this.destinationAccountId,
    this.destinationAmountMinor,
    this.destinationCurrencyCode,
    this.exchangeRate,
    this.paymentMethod = 'Cash',
    this.notes = '',
    this.receiptPath,
    this.recurringId,
    this.transferId,
    this.status = 'active',
    this.version = 1,
    this.syncStatus = SyncStatus.pending,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String accountId;
  final TransactionType type;
  final int amountMinor;
  final String currencyCode;
  final String category;
  final String description;
  final DateTime occurredAt;
  final String? destinationAccountId;
  final int? destinationAmountMinor;
  final String? destinationCurrencyCode;
  final String? exchangeRate;
  final String paymentMethod;
  final String notes;
  final String? receiptPath;
  final String? recurringId;
  final String? transferId;
  final String status;
  final int version;
  final SyncStatus syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  factory FinancialTransaction.fromMap(Map<String, Object?> map) {
    return FinancialTransaction(
      id: map['id']! as String,
      userId: map['user_id']! as String,
      accountId: map['account_id']! as String,
      type: TransactionType.values.byName(map['type']! as String),
      amountMinor: map['amount_minor']! as int,
      currencyCode: map['currency_code']! as String,
      category: map['category']! as String,
      description: map['description']! as String,
      occurredAt: _dateTime(map['transaction_date']) ?? DateTime.now(),
      destinationAccountId: map['destination_account_id'] as String?,
      destinationAmountMinor: map['destination_amount_minor'] as int?,
      destinationCurrencyCode: map['destination_currency_code'] as String?,
      exchangeRate: map['exchange_rate'] as String?,
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      notes: map['notes'] as String? ?? '',
      receiptPath: map['receipt_path'] as String?,
      recurringId: map['recurring_id'] as String?,
      transferId: map['transfer_id'] as String?,
      status: map['status'] as String? ?? 'active',
      version: map['version'] as int? ?? 1,
      syncStatus: _syncStatus(map['sync_status']),
      createdAt: _dateTime(map['created_at']),
      updatedAt: _dateTime(map['updated_at']),
      deletedAt: _dateTime(map['deleted_at']),
    );
  }

  Map<String, Object?> toMap({bool includeSync = true}) => {
    'id': id,
    'user_id': userId,
    'account_id': accountId,
    'type': type.name,
    'amount_minor': amountMinor,
    'currency_code': currencyCode,
    'category': category,
    'description': description,
    'transaction_date': occurredAt.millisecondsSinceEpoch,
    'destination_account_id': destinationAccountId,
    'destination_amount_minor': destinationAmountMinor,
    'destination_currency_code': destinationCurrencyCode,
    'exchange_rate': exchangeRate,
    'payment_method': paymentMethod,
    'notes': notes,
    'receipt_path': receiptPath,
    'recurring_id': recurringId,
    'transfer_id': transferId,
    'status': status,
    'version': version,
    if (includeSync) 'sync_status': syncStatus.name,
    'created_at': createdAt?.millisecondsSinceEpoch,
    'updated_at': updatedAt?.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
  };

  Map<String, Object?> toCloudMap() => {
    'id': id,
    'userId': userId,
    'accountId': accountId,
    'type': type.name,
    'amountMinor': amountMinor,
    'currencyCode': currencyCode,
    'category': category,
    'description': description,
    'transactionDate': occurredAt.millisecondsSinceEpoch,
    'destinationAccountId': destinationAccountId,
    'destinationAmountMinor': destinationAmountMinor,
    'destinationCurrencyCode': destinationCurrencyCode,
    'exchangeRate': exchangeRate,
    'paymentMethod': paymentMethod,
    'notes': notes,
    'receiptPath': receiptPath,
    'recurringId': recurringId,
    'transferId': transferId,
    'status': status,
    'version': version,
    'createdAt': createdAt?.millisecondsSinceEpoch,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
    'deletedAt': deletedAt?.millisecondsSinceEpoch,
  };

  FinancialTransaction copyWith({
    String? id,
    String? userId,
    String? accountId,
    TransactionType? type,
    int? amountMinor,
    String? currencyCode,
    String? category,
    String? description,
    DateTime? occurredAt,
    String? destinationAccountId,
    int? destinationAmountMinor,
    String? destinationCurrencyCode,
    String? exchangeRate,
    String? paymentMethod,
    String? notes,
    String? receiptPath,
    String? recurringId,
    String? transferId,
    String? status,
    int? version,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      category: category ?? this.category,
      description: description ?? this.description,
      occurredAt: occurredAt ?? this.occurredAt,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      destinationAmountMinor:
          destinationAmountMinor ?? this.destinationAmountMinor,
      destinationCurrencyCode:
          destinationCurrencyCode ?? this.destinationCurrencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      receiptPath: receiptPath ?? this.receiptPath,
      recurringId: recurringId ?? this.recurringId,
      transferId: transferId ?? this.transferId,
      status: status ?? this.status,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

class FinancialBudget {
  const FinancialBudget({
    required this.id,
    required this.userId,
    required this.name,
    required this.limitMinor,
    required this.currencyCode,
    required this.startDate,
    required this.endDate,
    this.categoryIds = const [],
    this.alertPercentage = 70,
    this.isArchived = false,
    this.syncStatus = SyncStatus.pending,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final int limitMinor;
  final String currencyCode;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> categoryIds;
  final int alertPercentage;
  final bool isArchived;
  final SyncStatus syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FinancialBudget.fromMap(Map<String, Object?> map) {
    return FinancialBudget(
      id: map['id']! as String,
      userId: map['user_id']! as String,
      name: map['name']! as String,
      limitMinor: map['limit_minor']! as int,
      currencyCode: map['currency_code']! as String,
      startDate: _dateTime(map['start_date']) ?? DateTime.now(),
      endDate: _dateTime(map['end_date']) ?? DateTime.now(),
      categoryIds: _decodeStringList(map['category_ids']),
      alertPercentage: map['alert_percentage'] as int? ?? 70,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      syncStatus: _syncStatus(map['sync_status']),
      createdAt: _dateTime(map['created_at']),
      updatedAt: _dateTime(map['updated_at']),
    );
  }

  Map<String, Object?> toMap({bool includeSync = true}) => {
    'id': id,
    'user_id': userId,
    'name': name,
    'limit_minor': limitMinor,
    'currency_code': currencyCode,
    'start_date': startDate.millisecondsSinceEpoch,
    'end_date': endDate.millisecondsSinceEpoch,
    'category_ids': categoryIds.join('|'),
    'alert_percentage': alertPercentage,
    'is_archived': isArchived ? 1 : 0,
    if (includeSync) 'sync_status': syncStatus.name,
    'created_at': createdAt?.millisecondsSinceEpoch,
    'updated_at': updatedAt?.millisecondsSinceEpoch,
  };

  Map<String, Object?> toCloudMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'limitMinor': limitMinor,
    'currencyCode': currencyCode,
    'startDate': startDate.millisecondsSinceEpoch,
    'endDate': endDate.millisecondsSinceEpoch,
    'categoryIds': categoryIds,
    'alertPercentage': alertPercentage,
    'isArchived': isArchived,
    'createdAt': createdAt?.millisecondsSinceEpoch,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
  };
}

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetMinor,
    required this.currencyCode,
    required this.targetDate,
    this.description = '',
    this.status = 'active',
    this.syncStatus = SyncStatus.pending,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final int targetMinor;
  final String currencyCode;
  final DateTime targetDate;
  final String description;
  final String status;
  final SyncStatus syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SavingsGoal.fromMap(Map<String, Object?> map) => SavingsGoal(
    id: map['id']! as String,
    userId: map['user_id']! as String,
    name: map['name']! as String,
    targetMinor: map['target_minor']! as int,
    currencyCode: map['currency_code']! as String,
    targetDate: _dateTime(map['target_date']) ?? DateTime.now(),
    description: map['description'] as String? ?? '',
    status: map['status'] as String? ?? 'active',
    syncStatus: _syncStatus(map['sync_status']),
    createdAt: _dateTime(map['created_at']),
    updatedAt: _dateTime(map['updated_at']),
  );

  Map<String, Object?> toMap({bool includeSync = true}) => {
    'id': id,
    'user_id': userId,
    'name': name,
    'target_minor': targetMinor,
    'currency_code': currencyCode,
    'target_date': targetDate.millisecondsSinceEpoch,
    'description': description,
    'status': status,
    if (includeSync) 'sync_status': syncStatus.name,
    'created_at': createdAt?.millisecondsSinceEpoch,
    'updated_at': updatedAt?.millisecondsSinceEpoch,
  };

  Map<String, Object?> toCloudMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'targetMinor': targetMinor,
    'currencyCode': currencyCode,
    'targetDate': targetDate.millisecondsSinceEpoch,
    'description': description,
    'status': status,
    'createdAt': createdAt?.millisecondsSinceEpoch,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
  };
}

class SavingsContribution {
  const SavingsContribution({
    required this.id,
    required this.userId,
    required this.goalId,
    required this.amountMinor,
    required this.currencyCode,
    required this.type,
    required this.occurredAt,
    this.accountId,
    this.notes = '',
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String userId;
  final String goalId;
  final int amountMinor;
  final String currencyCode;
  final String type;
  final DateTime occurredAt;
  final String? accountId;
  final String notes;
  final SyncStatus syncStatus;

  factory SavingsContribution.fromMap(Map<String, Object?> map) =>
      SavingsContribution(
        id: map['id']! as String,
        userId: map['user_id']! as String,
        goalId: map['goal_id']! as String,
        amountMinor: map['amount_minor']! as int,
        currencyCode: map['currency_code']! as String,
        type: map['type']! as String,
        occurredAt: _dateTime(map['contribution_date']) ?? DateTime.now(),
        accountId: map['account_id'] as String?,
        notes: map['notes'] as String? ?? '',
        syncStatus: _syncStatus(map['sync_status']),
      );

  Map<String, Object?> toMap({bool includeSync = true}) => {
    'id': id,
    'user_id': userId,
    'goal_id': goalId,
    'amount_minor': amountMinor,
    'currency_code': currencyCode,
    'type': type,
    'contribution_date': occurredAt.millisecondsSinceEpoch,
    'account_id': accountId,
    'notes': notes,
    if (includeSync) 'sync_status': syncStatus.name,
  };

  Map<String, Object?> toCloudMap() => {
    'id': id,
    'userId': userId,
    'goalId': goalId,
    'amountMinor': amountMinor,
    'currencyCode': currencyCode,
    'type': type,
    'contributionDate': occurredAt.millisecondsSinceEpoch,
    'accountId': accountId,
    'notes': notes,
  };
}

class DebtRecord {
  const DebtRecord({
    required this.id,
    required this.userId,
    required this.personName,
    required this.type,
    required this.principalMinor,
    required this.currencyCode,
    this.dueDate,
    this.notes = '',
    this.status = 'active',
    this.syncStatus = SyncStatus.pending,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String personName;
  final String type;
  final int principalMinor;
  final String currencyCode;
  final DateTime? dueDate;
  final String notes;
  final String status;
  final SyncStatus syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DebtRecord.fromMap(Map<String, Object?> map) => DebtRecord(
    id: map['id']! as String,
    userId: map['user_id']! as String,
    personName: map['person_name']! as String,
    type: map['debt_type']! as String,
    principalMinor: map['principal_minor']! as int,
    currencyCode: map['currency_code']! as String,
    dueDate: _dateTime(map['due_date']),
    notes: map['notes'] as String? ?? '',
    status: map['status'] as String? ?? 'active',
    syncStatus: _syncStatus(map['sync_status']),
    createdAt: _dateTime(map['created_at']),
    updatedAt: _dateTime(map['updated_at']),
  );

  Map<String, Object?> toMap({bool includeSync = true}) => {
    'id': id,
    'user_id': userId,
    'person_name': personName,
    'debt_type': type,
    'principal_minor': principalMinor,
    'currency_code': currencyCode,
    'due_date': dueDate?.millisecondsSinceEpoch,
    'notes': notes,
    'status': status,
    if (includeSync) 'sync_status': syncStatus.name,
    'created_at': createdAt?.millisecondsSinceEpoch,
    'updated_at': updatedAt?.millisecondsSinceEpoch,
  };

  Map<String, Object?> toCloudMap() => {
    'id': id,
    'userId': userId,
    'personName': personName,
    'type': type,
    'principalMinor': principalMinor,
    'currencyCode': currencyCode,
    'dueDate': dueDate?.millisecondsSinceEpoch,
    'notes': notes,
    'status': status,
    'createdAt': createdAt?.millisecondsSinceEpoch,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
  };
}

class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.userId,
    required this.debtId,
    required this.amountMinor,
    required this.paymentType,
    required this.paymentDate,
    this.accountId,
    this.notes = '',
  });

  final String id;
  final String userId;
  final String debtId;
  final int amountMinor;
  final String paymentType;
  final DateTime paymentDate;
  final String? accountId;
  final String notes;

  factory DebtPayment.fromMap(Map<String, Object?> map) => DebtPayment(
    id: map['id']! as String,
    userId: map['user_id']! as String,
    debtId: map['debt_id']! as String,
    amountMinor: map['amount_minor']! as int,
    paymentType: map['payment_type']! as String,
    paymentDate: _dateTime(map['payment_date']) ?? DateTime.now(),
    accountId: map['account_id'] as String?,
    notes: map['notes'] as String? ?? '',
  );

  Map<String, Object?> toMap({bool includeSync = true}) => {
    'id': id,
    'user_id': userId,
    'debt_id': debtId,
    'amount_minor': amountMinor,
    'payment_type': paymentType,
    'account_id': accountId,
    'payment_date': paymentDate.millisecondsSinceEpoch,
    'notes': notes,
    if (includeSync) 'sync_status': SyncStatus.pending.name,
  };
}

class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.type,
    required this.amountMinor,
    required this.currencyCode,
    required this.category,
    required this.description,
    required this.frequency,
    required this.nextOccurrence,
    this.endDate,
    this.isActive = true,
    this.syncStatus = SyncStatus.pending,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String accountId;
  final String type;
  final int amountMinor;
  final String currencyCode;
  final String category;
  final String description;
  final String frequency;
  final DateTime nextOccurrence;
  final DateTime? endDate;
  final bool isActive;
  final SyncStatus syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RecurringRule.fromMap(Map<String, Object?> map) => RecurringRule(
    id: map['id']! as String,
    userId: map['user_id']! as String,
    accountId: map['account_id']! as String,
    type: map['type']! as String,
    amountMinor: map['amount_minor']! as int,
    currencyCode: map['currency_code']! as String,
    category: map['category']! as String,
    description: map['description']! as String,
    frequency: map['frequency']! as String,
    nextOccurrence: _dateTime(map['next_occurrence']) ?? DateTime.now(),
    endDate: _dateTime(map['end_date']),
    isActive: (map['is_active'] as int? ?? 1) == 1,
    syncStatus: _syncStatus(map['sync_status']),
    createdAt: _dateTime(map['created_at']),
    updatedAt: _dateTime(map['updated_at']),
  );

  Map<String, Object?> toMap({bool includeSync = true}) => {
    'id': id,
    'user_id': userId,
    'account_id': accountId,
    'type': type,
    'amount_minor': amountMinor,
    'currency_code': currencyCode,
    'category': category,
    'description': description,
    'frequency': frequency,
    'next_occurrence': nextOccurrence.millisecondsSinceEpoch,
    'end_date': endDate?.millisecondsSinceEpoch,
    'is_active': isActive ? 1 : 0,
    if (includeSync) 'sync_status': syncStatus.name,
    'created_at': createdAt?.millisecondsSinceEpoch,
    'updated_at': updatedAt?.millisecondsSinceEpoch,
  };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final bool isRead;

  factory AppNotification.fromMap(Map<String, Object?> map) => AppNotification(
    id: map['id']! as String,
    userId: map['user_id']! as String,
    title: map['title']! as String,
    body: map['body']! as String,
    type: map['type']! as String,
    createdAt: _dateTime(map['created_at']) ?? DateTime.now(),
    isRead: (map['is_read'] as int? ?? 0) == 1,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'body': body,
    'type': type,
    'created_at': createdAt.millisecondsSinceEpoch,
    'is_read': isRead ? 1 : 0,
  };
}

@immutable
class CurrencyAmount {
  const CurrencyAmount(this.currencyCode, this.amountMinor);

  final String currencyCode;
  final int amountMinor;
}

SyncStatus _syncStatus(Object? value) {
  return SyncStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => SyncStatus.pending,
  );
}

DateTime? _dateTime(Object? value) {
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is DateTime) return value;
  return null;
}

List<String> _decodeStringList(Object? value) {
  if (value is List) return value.whereType<String>().toList();
  if (value is String && value.isNotEmpty) return value.split('|');
  return const [];
}
