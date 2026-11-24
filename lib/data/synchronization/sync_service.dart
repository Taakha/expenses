import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../repositories/finance_repository.dart';

enum SyncState { offline, synchronizing, synced, needsAttention }

class SyncService {
  SyncService({
    FinanceRepository? repository,
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
  }) : _repository = repository ?? FinanceRepository(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _connectivity = connectivity ?? Connectivity();

  final FinanceRepository _repository;
  final FirebaseFirestore _firestore;
  final Connectivity _connectivity;
  SyncState state = SyncState.offline;
  String? lastError;
  int pendingCount = 0;

  Future<bool> hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> synchronize(String uid) async {
    if (!await hasConnection()) {
      state = SyncState.offline;
      pendingCount = await _repository.pendingSyncCount(uid);
      return;
    }

    state = SyncState.synchronizing;
    lastError = null;
    var afterId = 0;
    while (true) {
      final pending = await _repository.pendingSync(uid, afterId: afterId);
      if (pending.isEmpty) break;
      for (final item in pending) {
        final queueId = item['id']! as int;
        afterId = queueId;
        final collection = item['collection_name']! as String;
        final id = item['record_id']! as String;
        final operation = item['operation']! as String;
        try {
          final reference = _firestore
              .collection('users')
              .doc(uid)
              .collection(collection)
              .doc(id);
          if (operation == 'delete') {
            await reference.delete();
          } else {
            final local = await _repository.recordForSync(collection, id, uid);
            if (local == null) {
              await reference.delete();
            } else {
              final cloud = await reference.get();
              if (cloud.exists) {
                final remoteData = cloud.data();
                final localVersion = (local['version'] as int?) ?? 1;
                final remoteVersion = (remoteData?['version'] as int?) ?? 1;
                if (remoteVersion >= localVersion &&
                    !_sameRecord(local, remoteData)) {
                  lastError =
                      'A $collection record changed on another device. Resolve the conflict before syncing.';
                  await _repository.markSyncConflict(
                    uid: uid,
                    collection: collection,
                    recordId: id,
                    localRecord: local,
                    remoteRecord: remoteData ?? const {},
                  );
                  continue;
                }
              }
              final clean = Map<String, Object?>.from(local)
                ..remove('sync_status');
              await reference.set(clean);
            }
          }
          await _repository.markSynced(uid, collection, id);
        } catch (error) {
          lastError = error.toString();
          await _repository.markSyncFailed(queueId, lastError!);
        }
      }
    }

    await _pullRemote(uid);
    pendingCount = await _repository.pendingSyncCount(uid);
    final conflicts = await _repository.syncConflicts(uid);
    if (conflicts.isNotEmpty && lastError == null) {
      lastError =
          '${conflicts.length} financial change conflict(s) need review.';
    }
    state = lastError == null && pendingCount == 0
        ? SyncState.synced
        : SyncState.needsAttention;
  }

  Future<void> _pullRemote(String uid) async {
    for (final collection in FinanceRepository.syncCollections) {
      final reference = _firestore
          .collection('users')
          .doc(uid)
          .collection(collection);
      QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
      try {
        while (true) {
          Query<Map<String, dynamic>> query = reference
              .orderBy(FieldPath.documentId)
              .limit(500);
          if (lastDocument != null) {
            query = query.startAfterDocument(lastDocument);
          }
          final snapshot = await query.get();
          if (snapshot.docs.isEmpty) break;
          for (final document in snapshot.docs) {
            final data = Map<String, Object?>.from(document.data());
            data['id'] = document.id;
            data['user_id'] ??= uid;
            await _repository.applyRemoteRecord(uid, collection, data);
          }
          lastDocument = snapshot.docs.last;
          if (snapshot.docs.length < 500) break;
        }
      } catch (error) {
        lastError ??= error.toString();
      }
    }
  }

  static bool _sameRecord(
    Map<String, Object?> local,
    Map<String, dynamic>? remote,
  ) {
    if (remote == null) return false;
    final normalizedLocal = Map<String, Object?>.from(local)
      ..remove('sync_status');
    final normalizedRemote = Map<String, Object?>.from(remote)
      ..remove('sync_status');
    return jsonEncode(_canonical(normalizedLocal)) ==
        jsonEncode(_canonical(normalizedRemote));
  }

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is Iterable) return value.map(_canonical).toList();
    return value;
  }
}
