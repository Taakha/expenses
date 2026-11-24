import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/local/app_database.dart';

class BackupService {
  const BackupService();

  Future<String> createBackup(String uid) async {
    final db = await AppDatabase.instance.database;
    final checkpoint = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    if (checkpoint.isNotEmpty && (checkpoint.first['busy'] as int? ?? 0) != 0) {
      throw StateError('The database is busy. Try creating the backup again.');
    }

    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(base.path, 'moneywise', 'backups'));
    if (!await directory.exists()) await directory.create(recursive: true);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(path.join(directory.path, 'moneywise_$timestamp.db'));
    final receiptBackup = Directory('${file.path}_receipts');
    try {
      await File(db.path).copy(file.path);
      final receipts = Directory(
        path.join(base.path, 'moneywise', 'receipts'),
      );
      if (await receipts.exists()) {
        await _copyDirectory(receipts, receiptBackup);
      } else {
        await receiptBackup.create(recursive: true);
      }
      await _verifyBackup(file, uid);
      await db.insert('backup_records', {
        'id': timestamp.toString(),
        'user_id': uid,
        'local_path': file.path,
        'version': 1,
        'created_at': timestamp,
        'verified': 1,
        'status': 'complete',
      });
      return file.path;
    } on Object {
      if (await file.exists()) await file.delete();
      if (await receiptBackup.exists()) {
        await receiptBackup.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> listBackups(String uid) async {
    final db = await AppDatabase.instance.database;
    final records = await db.query(
      'backup_records',
      where: 'user_id = ? AND status = ?',
      whereArgs: [uid, 'complete'],
      orderBy: 'created_at DESC',
    );
    final valid = <Map<String, Object?>>[];
    for (final record in records) {
      final localPath = record['local_path'] as String?;
      if (localPath != null && await File(localPath).exists()) valid.add(record);
    }
    return valid;
  }

  Future<void> restoreBackup({
    required String uid,
    required String backupPath,
  }) async {
    final source = File(backupPath);
    if (!await source.exists()) {
      throw const FileSystemException('Backup file does not exist.');
    }
    await _verifyBackup(source, uid);

    final db = await AppDatabase.instance.database;
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    final databasePath = db.path;
    final safetyPath = '$databasePath.before_restore';
    final base = await getApplicationDocumentsDirectory();
    final receiptDirectory = Directory(
      path.join(base.path, 'moneywise', 'receipts'),
    );
    final receiptBackup = Directory('${backupPath}_receipts');
    final stagedReceipts = Directory('${receiptDirectory.path}.restore');
    final safetyReceipts = Directory('${receiptDirectory.path}.before_restore');
    var receiptsReplaced = false;
    await File(databasePath).copy(safetyPath);
    await AppDatabase.instance.close();
    try {
      await source.copy(databasePath);
      final restored = await AppDatabase.instance.database;
      final userRows = await restored.query(
        'users',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [uid],
        limit: 1,
      );
      if (userRows.isEmpty) {
        throw StateError('The restored backup does not contain this account.');
      }
      if (await receiptBackup.exists()) {
        if (await stagedReceipts.exists()) {
          await stagedReceipts.delete(recursive: true);
        }
        await _copyDirectory(receiptBackup, stagedReceipts);
        if (await safetyReceipts.exists()) {
          await safetyReceipts.delete(recursive: true);
        }
        if (await receiptDirectory.exists()) {
          await receiptDirectory.rename(safetyReceipts.path);
          receiptsReplaced = true;
        }
        await stagedReceipts.rename(receiptDirectory.path);
        receiptsReplaced = true;
      }
      if (await safetyReceipts.exists()) {
        await safetyReceipts.delete(recursive: true);
      }
    } catch (_) {
      await AppDatabase.instance.close();
      await File(safetyPath).copy(databasePath);
      if (receiptsReplaced && await receiptDirectory.exists()) {
        await receiptDirectory.delete(recursive: true);
      }
      if (await safetyReceipts.exists()) {
        await safetyReceipts.rename(receiptDirectory.path);
      }
      if (await stagedReceipts.exists()) {
        await stagedReceipts.delete(recursive: true);
      }
      rethrow;
    } finally {
      final safetyFile = File(safetyPath);
      if (await safetyFile.exists()) await safetyFile.delete();
    }
  }

  Future<void> _verifyBackup(File file, String uid) async {
    final backup = await openDatabase(
      file.path,
      readOnly: true,
      singleInstance: false,
    );
    try {
      final integrity = await backup.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw StateError('The backup database failed its integrity check.');
      }
      final user = await backup.query(
        'users',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [uid],
        limit: 1,
      );
      if (user.isEmpty) {
        throw StateError('The backup does not belong to the signed-in account.');
      }
    } finally {
      await backup.close();
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: true)) {
      final relativePath = path.relative(entity.path, from: source.path);
      final destinationPath = path.join(destination.path, relativePath);
      if (entity is Directory) {
        await Directory(destinationPath).create(recursive: true);
      } else if (entity is File) {
        await Directory(path.dirname(destinationPath)).create(recursive: true);
        await entity.copy(destinationPath);
      }
    }
  }
}
