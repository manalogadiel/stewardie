import 'dart:async';
// Temporary compatibility boundary for the existing FlutterFire-typed screens.
// These SDK annotations are advisory; no private delegates are accessed.
// ignore_for_file: subtype_of_sealed_class
import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'core_data_client.dart';

/// Compatibility view for existing Flutter screens. Persistence is exclusively
/// Supabase; unsupported Firestore operations fail rather than falling back.
class CoreFirestore implements FirebaseFirestore {
  CoreFirestore(this.client);
  final CoreDataClient client;
  final changes = StreamController<void>.broadcast();
  final _random = Random.secure();
  String newId() => List.generate(
    20,
    (_) =>
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'[_random
            .nextInt(62)],
  ).join();
  @override
  CoreDocument doc(String path) => CoreDocument(this, path);
  @override
  CoreCollection collection(String path) => CoreCollection(this, path);
  @override
  CoreBatch batch() => CoreBatch(this);
  void notify() => changes.add(null);
  Future<void> write(Map<String, dynamic> values) async {
    await client.call('docWrite', values);
    notify();
  }

  Stream<T> watch<T>(Future<T> Function() load) => Stream.multi((sink) {
    var busy = false, again = false, closed = false;
    Future<void> refresh() async {
      if (closed) return;
      if (busy) {
        again = true;
        return;
      }
      busy = true;
      do {
        again = false;
        try {
          final value = await load();
          if (!closed) sink.add(value);
        } catch (error, stack) {
          if (!closed) sink.addError(error, stack);
        }
      } while (again && !closed);
      busy = false;
    }

    final subscription = changes.stream.listen((_) => unawaited(refresh()));
    final lifecycle = _VisibleWatch(() => unawaited(refresh()));
    lifecycle.start();
    unawaited(refresh());
    sink.onCancel = () {
      closed = true;
      lifecycle.dispose();
      subscription.cancel();
    };
  });
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    throw UnsupportedError('Use a protected SQL workflow for transactions.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unsupported Supabase document operation: ${invocation.memberName}',
  );
}

dynamic coreEncode(dynamic value) {
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is FieldValue) {
    if (value == FieldValue.serverTimestamp()) return {'_serverTime': true};
    throw UnsupportedError('Use a protected workflow for field transforms.');
  }
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), coreEncode(v)));
  }
  if (value is List) return value.map(coreEncode).toList();
  return value;
}

dynamic coreDecode(dynamic value, {String? field}) {
  if (value is Map) {
    return value.map(
      (k, v) => MapEntry(k.toString(), coreDecode(v, field: k.toString())),
    );
  }
  if (value is List) return value.map((v) => coreDecode(v)).toList();
  if (value is String &&
      (field?.endsWith('At') == true || field == 'expiresAt') &&
      DateTime.tryParse(value) != null) {
    return Timestamp.fromDate(DateTime.parse(value));
  }
  return value;
}

class CoreDocument implements DocumentReference<Map<String, dynamic>> {
  CoreDocument(this.store, this.path);
  final CoreFirestore store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  FirebaseFirestore get firestore => store;
  @override
  CoreCollection get parent =>
      CoreCollection(store, path.substring(0, path.lastIndexOf('/')));
  @override
  CoreCollection collection(String name) =>
      CoreCollection(store, '$path/$name');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    final result = await store.client.read('docRead', {'path': path});
    return CoreSnapshot(
      this,
      result['data'] == null
          ? null
          : Map<String, dynamic>.from(coreDecode(result['data']) as Map),
    );
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => store.watch(() => get());
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) =>
      store.write({
        'path': path,
        'mode': options?.merge == true ? 'merge' : 'set',
        'data': coreEncode(data),
      });
  @override
  Future<void> update(Map<Object, Object?> data) =>
      store.write({'path': path, 'mode': 'update', 'data': coreEncode(data)});
  @override
  Future<void> delete() => store.write({'path': path, 'mode': 'delete'});
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unsupported document operation: ${invocation.memberName}',
  );
}

class CoreSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  CoreSnapshot(this.reference, this.value);
  final Map<String, dynamic>? value;
  @override
  final CoreDocument reference;
  @override
  String get id => reference.id;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
  @override
  dynamic get(Object field) => value?[field.toString()];
  @override
  dynamic operator [](Object field) => get(field);
  @override
  SnapshotMetadata get metadata => const CoreMetadata();
}

class CoreQueryDocument extends CoreSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  CoreQueryDocument(super.reference, Map<String, dynamic> super.value);
  @override
  Map<String, dynamic> data() => value!;
}

class CoreMetadata implements SnapshotMetadata {
  const CoreMetadata();
  @override
  bool get isFromCache => false;
  @override
  bool get hasPendingWrites => false;
}

class CoreQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  CoreQuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  int get size => docs.length;
  @override
  SnapshotMetadata get metadata => const CoreMetadata();
  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => const [];
}

class CoreQuery implements Query<Map<String, dynamic>> {
  CoreQuery(
    this.store,
    this.path, {
    this.filters = const [],
    this.order,
    this.descending = false,
    this.maximum,
    this.afterId,
    this.activeOnly = false,
  });
  final CoreFirestore store;
  final String path;
  final List<bool Function(Map<String, dynamic>)> filters;
  final String? order, afterId;
  final bool descending;
  final bool activeOnly;
  final int? maximum;
  CoreQuery copy({
    List<bool Function(Map<String, dynamic>)>? filters,
    String? order,
    bool? descending,
    int? maximum,
    String? afterId,
    bool? activeOnly,
  }) => CoreQuery(
    store,
    path,
    filters: filters ?? this.filters,
    order: order ?? this.order,
    descending: descending ?? this.descending,
    maximum: maximum ?? this.maximum,
    afterId: afterId ?? this.afterId,
    activeOnly: activeOnly ?? this.activeOnly,
  );
  @override
  FirebaseFirestore get firestore => store;
  @override
  CoreQuery where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    bool test(Map<String, dynamic> data) {
      final v = data[field.toString()];
      if (isNull != null) return (v == null) == isNull;
      if (isEqualTo != null) return v == isEqualTo;
      if (isNotEqualTo != null) return v != isNotEqualTo;
      if (arrayContains != null) return v is List && v.contains(arrayContains);
      if (arrayContainsAny != null) {
        return v is List && arrayContainsAny.any(v.contains);
      }
      if (whereIn != null) return whereIn.contains(v);
      if (whereNotIn != null) return !whereNotIn.contains(v);
      if (v == null) return false;
      if (isLessThan != null) return compare(v, isLessThan) < 0;
      if (isLessThanOrEqualTo != null) {
        return compare(v, isLessThanOrEqualTo) <= 0;
      }
      if (isGreaterThan != null) return compare(v, isGreaterThan) > 0;
      if (isGreaterThanOrEqualTo != null) {
        return compare(v, isGreaterThanOrEqualTo) >= 0;
      }
      return true;
    }

    return copy(
      filters: [...filters, test],
      activeOnly:
          activeOnly || (field == 'status' && isNotEqualTo == 'completed'),
    );
  }

  static int compare(dynamic a, dynamic b) => a is Timestamp && b is Timestamp
      ? a.compareTo(b)
      : a is num && b is num
      ? a.compareTo(b)
      : a.toString().compareTo(b.toString());
  @override
  CoreQuery orderBy(Object field, {bool descending = false}) =>
      copy(order: field.toString(), descending: descending);
  @override
  CoreQuery limit(int limit) => copy(maximum: limit);
  @override
  CoreQuery startAfterDocument(DocumentSnapshot documentSnapshot) =>
      copy(afterId: documentSnapshot.id);
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final result = await store.client.read('docList', {
      'path': path,
      if (activeOnly) 'activeOnly': true,
    });
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
      for (final row in result['rows'] as List? ?? [])
        CoreQueryDocument(
          store.doc('$path/${row['id']}'),
          Map<String, dynamic>.from(coreDecode(row['data']) as Map),
        ),
    ].where((d) => filters.every((test) => test(d.data()))).toList();
    if (order != null) {
      docs.sort(
        (a, b) =>
            compare(a.data()[order], b.data()[order]) * (descending ? -1 : 1),
      );
    }
    final offset = afterId == null
        ? 0
        : docs.indexWhere((d) => d.id == afterId) + 1;
    return CoreQuerySnapshot(
      docs.skip(offset).take(maximum ?? docs.length).toList(),
    );
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => store.watch(() => get());
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unsupported query operation: ${invocation.memberName}',
  );
}

class CoreCollection extends CoreQuery
    implements CollectionReference<Map<String, dynamic>> {
  CoreCollection(super.store, super.path);
  @override
  String get id => path.split('/').last;
  @override
  CoreDocument? get parent => path.contains('/')
      ? store.doc(path.substring(0, path.lastIndexOf('/')))
      : null;
  @override
  CoreDocument doc([String? path]) =>
      store.doc('${this.path}/${path ?? store.newId()}');
  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) async {
    final ref = doc();
    await ref.set(data);
    return ref;
  }
}

class CoreBatch implements WriteBatch {
  CoreBatch(this.store);
  final CoreFirestore store;
  final writes = <Map<String, dynamic>>[];
  @override
  void set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) =>
      writes.add({
        'path': ref.path,
        'mode': options?.merge == true ? 'merge' : 'set',
        'data': coreEncode(data),
      });
  @override
  void update<T>(DocumentReference<T> ref, T data) => writes.add({
    'path': ref.path,
    'mode': 'update',
    'data': coreEncode(data),
  });
  @override
  void delete(DocumentReference ref) =>
      writes.add({'path': ref.path, 'mode': 'delete'});
  @override
  Future<void> commit() async {
    if (writes.isEmpty) return;
    await store.client.call('docBatch', {'writes': writes});
    store.notify();
  }
}

/// Foreground fallback polling; mutations still invalidate immediately.
class _VisibleWatch with WidgetsBindingObserver {
  _VisibleWatch(this.refresh);
  final VoidCallback refresh;
  Timer? timer;
  void start() {
    WidgetsFlutterBinding.ensureInitialized().addObserver(this);
    if (WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _arm();
    }
  }

  void _arm() {
    timer ??= Timer.periodic(const Duration(seconds: 45), (_) => refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
      _arm();
    } else {
      timer?.cancel();
      timer = null;
    }
  }

  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
