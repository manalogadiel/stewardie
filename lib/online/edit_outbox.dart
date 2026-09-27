import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import 'online_backend.dart';

/// Durable, account-scoped intent queue. Remote Firestore acknowledgement is
/// the source of truth; queued items are never presented as confirmed writes.
class EditOutbox extends ChangeNotifier {
  EditOutbox(this.database, this.backend, this.uid)
      : _store = stringMapStoreFactory.store('edit-outbox-$uid');

  final Database database;
  final OnlineBackend backend;
  final String uid;
  final StoreRef<String, Map<String, Object?>> _store;
  final Map<String, Map<String, Object?>> _items = {};
  Timer? _timer;
  bool _flushing = false, _closed = false;

  Iterable<Map<String, Object?>> get items => _items.values;
  int get unsyncedCount => _items.values.where((item) => item['status'] != 'synced').length;

  Future<void> start() async {
    for (final record in await _store.find(database)) {
      _items[record.key] = record.value;
    }
    if (_closed) return;
    notifyListeners();
    unawaited(flush());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => unawaited(flush()));
  }

  Future<void> add(String id, String spaceId, String kind, Map<String, Object?> payload) async {
    if (_closed || backend.auth.currentUser?.uid != uid) {
      throw StateError('Sign in again to save this change.');
    }
    final item = <String, Object?>{
      'id': id, 'spaceId': spaceId, 'kind': kind, 'payload': payload,
      'status': 'pending', 'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _store.record(id).put(database, item);
    _items[id] = item;
    notifyListeners();
    unawaited(flush());
  }

  Future<void> flush({bool retryFailed = false}) async {
    if (_closed || _flushing || backend.auth.currentUser?.uid != uid) return;
    _flushing = true;
    try {
      for (final item in _items.values.toList()) {
        if (_closed || backend.auth.currentUser?.uid != uid) return;
        if (item['status'] == 'synced' ||
            (item['status'] == 'failed' && !retryFailed)) continue;
        final payload = Map<String, dynamic>.from(item['payload'] as Map);
        try {
          await backend.call(switch (item['kind']) {
            'taskCreate' => 'createTask',
            'planSave' => 'savePlan',
            'planRemove' => 'removePlan',
            _ => throw StateError('Unknown queued edit.'),
          }, payload);
          item['status'] = 'synced';
          item.remove('error');
        } catch (error) {
          final unavailable = error is FirebaseException &&
              ['unavailable', 'deadline-exceeded', 'network-request-failed'].contains(error.code);
          item['status'] = unavailable ? 'pending' : 'failed';
          item['error'] = unavailable
              ? 'Waiting for connection'
              : 'Could not sync this change. Review it and retry.';
        }
        await _store.record(item['id'] as String).put(database, item);
        notifyListeners();
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> acknowledged(String id) async {
    if (_items.remove(id) == null) return;
    await _store.record(id).delete(database);
    if (!_closed) notifyListeners();
  }

  Future<void> discardSpace(String spaceId) async {
    for (final item in _items.values.where((item) => item['spaceId'] == spaceId).toList()) {
      await acknowledged(item['id'] as String);
    }
  }

  void close() {
    _closed = true;
    _timer?.cancel();
    super.dispose();
  }
}
