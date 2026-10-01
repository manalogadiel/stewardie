import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sembast/sembast.dart';

import '../features/media/media_library.dart';
import '../core/place_pin.dart';
import '../core/sound_feedback.dart';
import '../features/timeline/domain/models.dart';
import 'firebase_repository.dart';
import 'online_backend.dart';

/// Only this endpoint is public configuration; no Supabase service key in Flutter.
const mediaEndpoint = String.fromEnvironment(
  'MEDIA_GATEWAY_URL',
  defaultValue: 'https://ulexhxfxatzlobabitpr.supabase.co/functions/v1/media',
);

class CloudMediaLibrary extends MediaLibrary {
  CloudMediaLibrary(
    FirebaseTimelineRepository timeline, {
    required this.user,
    required Database super.database,
    required StoreRef<String, Map<String, Object?>> super.records,
    required super.initial,
    required this._pending,
    http.Client? client,
    this._auth,
  }) : _client = client ?? http.Client(),
       super(timeline) {
    _subscription = timeline.changes.listen((_) {
      final allowed = timeline.spaces.map((s) => s.id).toSet();
      _remote.removeWhere((_, value) => !allowed.contains(value.spaceId));
      if (!_closed) notifyListeners();
    });
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_closed && _pending.isNotEmpty) unawaited(retryPending());
    });
    unawaited(retryPending());
  }
  final User user;
  final FirebaseAuth? _auth;
  final http.Client _client;
  final Map<String, MediaAttachment> _remote = {};
  final Map<String, Uint8List> _fullCache = {};
  final Set<String> _pending, _refreshing = {};
  final Map<String, DateTime> _lastRefresh = {};
  StreamSubscription<void>? _subscription;
  Timer? _retryTimer;
  bool _closed = false, _uploading = false;
  String? _error;
  static String get outboxName =>
      OnlineBackend.useSupabaseCore && !OnlineBackend.useEmulator
      ? 'core-shared-photo-outbox'
      : 'shared-photo-outbox';
  final _outbox = stringMapStoreFactory.store(outboxName);
  @override
  bool get supportsSharing => true;
  @override
  bool get enforceLocalQuotas => false;
  @override
  bool get syncing => _uploading || _refreshing.isNotEmpty;
  @override
  String? get syncError => _error;
  @override
  Set<String> get pendingIds => Set.unmodifiable(_pending);
  bool _allowed(String space) =>
      !_closed && timeline.spaces.any((s) => s.id == space);
  @override
  List<MediaAttachment> get items {
    final result = <String, MediaAttachment>{
      for (final p in super.items.where((p) => !p.cloud)) p.id: p,
    };
    result.addAll(_remote);
    return result.values.where((p) => _allowed(p.spaceId)).toList();
  }

  @override
  List<MediaAttachment> forTask(String id) =>
      items.where((p) => p.taskId == id).toList();
  Future<Map<String, String>> _headers() async {
    String? currentUid;
    try {
      currentUid =
          _auth?.currentUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      currentUid = user.uid;
    }
    if (_closed || (currentUid != null && user.uid != currentUid)) {
      throw StateError('Sign in again to share photos.');
    }
    final token = await user.getIdToken();
    if (token == null) throw StateError('Sign in again to share photos.');
    return {'Authorization': 'Bearer $token'};
  }

  Future<List<Map<String, dynamic>>> reactions(
    MediaAttachment photo, {
    String? type,
    bool change = false,
  }) async {
    if (!_allowed(photo.spaceId)) throw StateError('Space access ended.');
    final response = await _request({
      'action': change ? 'react' : 'reactions',
      'space': photo.spaceId,
      'id': photo.id,
      if (change) 'type': type,
    });
    if (!_allowed(photo.spaceId)) throw StateError('Space access ended.');
    return (jsonDecode(response.body)['reactions'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<http.Response> _request(Map<String, Object?> body) async {
    final response = await _client
        .post(
          Uri.parse(mediaEndpoint),
          headers: {...await _headers(), 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 35));
    _validate(response);
    return response;
  }

  void _validate(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message =
        'Could not connect to photo sharing. Your photo is kept for retry.';
    try {
      final body = jsonDecode(response.body);
      if (body['error'] is String) message = body['error'];
    } catch (_) {}
    if (kDebugMode) {
      debugPrint('Stewardie media failed (${response.statusCode}): $message');
    }
    throw StateError(message);
  }

  Future<MediaAttachment> _decode(Map<String, dynamic> row) async {
    final id = row['id'] as String, space = row['space_id'] as String;
    final existing =
        _remote[id] ?? super.items.where((p) => p.id == id).firstOrNull;
    final thumb =
        existing?.photo.thumbnail ??
        (await _request({
          'action': 'download',
          'space': space,
          'id': id,
          'thumbnail': true,
        })).bodyBytes;
    final framingMap = row['framing'] is String
        ? jsonDecode(row['framing'] as String) as Map<String, dynamic>?
        : (row['framing'] is Map
              ? Map<String, dynamic>.from(row['framing'] as Map)
              : null);
    final framing = FramingRect.fromMap(framingMap);
    return MediaAttachment(
      id: id,
      spaceId: space,
      uploaderId: row['uploader_uid'],
      caption: row['caption'],
      createdAt: DateTime.parse(row['created_at']),
      taskId: row['task_id'],
      taskTitle: row['task_title'],
      completedBy: row['completed_by'],
      publishedAt: row['published_at'] == null
          ? null
          : DateTime.parse(row['published_at']),
      cloud: true,
      framing: framing,
      pin: PlacePin.fromMap(row['pin']),
      photo: PhotoDraft(
        existing?.photo.bytes ?? thumb,
        thumb,
        row['width'],
        row['height'],
        'shared',
        framing: framing,
      ),
    );
  }

  @override
  Future<void> refresh(String spaceId) async {
    if (!_allowed(spaceId) || !_refreshing.add(spaceId)) return;
    final last = _lastRefresh[spaceId];
    if (last != null && DateTime.now().difference(last).inSeconds < 8) {
      _refreshing.remove(spaceId);
      return;
    }
    _lastRefresh[spaceId] = DateTime.now();
    try {
      final fetched = <String, MediaAttachment>{};
      int? offset = 0;
      while (offset != null && _allowed(spaceId)) {
        final data = jsonDecode(
          (await _request({
            'action': 'list',
            'space': spaceId,
            'offset': offset,
          })).body,
        );
        final rawItems = (data['items'] as List)
            .map((raw) => Map<String, dynamic>.from(raw as Map))
            .toList();
        final decodedItems = await Future.wait(
          rawItems.map((raw) => _decode(raw)),
        );
        for (final item in decodedItems) {
          fetched[item.id] = item;
        }
        offset = data['nextOffset'] as int?;
      }
      if (!_allowed(spaceId)) return;
      _remote.removeWhere((_, p) => p.spaceId == spaceId);
      _remote.addAll(fetched);
      _error = null;
    } catch (e) {
      if (e is StateError &&
          (e.message.contains('access') ||
              e.message.contains('permission') ||
              e.message.contains('not a member'))) {
        _remote.removeWhere((_, p) => p.spaceId == spaceId);
      }
      _error = e is StateError
          ? e.message
          : 'Could not refresh shared photos. Try again.';
    } finally {
      _refreshing.remove(spaceId);
      if (!_closed) notifyListeners();
    }
  }

  @override
  Future<MediaAttachment> add(
    PhotoDraft photo,
    String space,
    String actor,
    String caption, {
    String? taskId,
    PlacePin? pin,
    String? attachmentId,
  }) async {
    final saved = await super.add(
      photo,
      space,
      actor,
      caption,
      taskId: taskId,
      pin: pin,
      attachmentId: attachmentId,
    );
    await share(saved);
    return saved;
  }

  @override
  Future<void> share(MediaAttachment photo) async {
    if (photo.uploaderId != user.uid || !_allowed(photo.spaceId)) {
      throw StateError('You cannot share this photo.');
    }
    _soundIntents[photo.id] = SoundFeedback.captureIntent();
    _pending.add(photo.id);
    await _outbox.record('${user.uid}/${photo.id}').put(database!, {
      'id': photo.id,
      'uid': user.uid,
    });
    if (!_closed) notifyListeners();
    unawaited(retryPending());
  }

  @override
  Future<void> retryPending() {
    if (_closed) return Future.value();
    return _uploadRun ??= Future<void>(() => _drainPending())
        .whenComplete(() => _uploadRun = null);
  }

  final Map<String, SoundIntent?> _soundIntents = {};
  Future<void>? _uploadRun;
  Future<void> _drainPending() async {
    if (_uploading || _closed) return;
    _uploading = true;
    _error = null;
    notifyListeners();
    try {
      final attempted = <String>{};
      while (true) {
        final id = _pending.where((id) => !attempted.contains(id)).firstOrNull;
        if (id == null) break;
        attempted.add(id);
        final soundIntent = _soundIntents.remove(id);
        final photo = super.items.where((p) => p.id == id).firstOrNull;
        if (photo == null || !_allowed(photo.spaceId)) continue;
        try {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$mediaEndpoint?action=upload'),
          );
          request.headers.addAll(await _headers());
          request.fields.addAll({
            'id': id,
            'space': photo.spaceId,
            'caption': photo.caption,
            if (photo.taskId != null) 'task': photo.taskId!,
            'framing': jsonEncode(photo.framing.toMap()),
            'photoSource': photo.photo.source,
            if (photo.pin != null) 'pin': jsonEncode(photo.pin!.toMap()),
          });
          request.files.add(
            http.MultipartFile.fromBytes(
              'photo',
              photo.photo.bytes,
              filename: 'photo.jpg',
            ),
          );
          request.files.add(
            http.MultipartFile.fromBytes(
              'thumbnail',
              photo.photo.thumbnail,
              filename: 'thumb.jpg',
            ),
          );
          final response = await http.Response.fromStream(
            await _client.send(request),
          ).timeout(const Duration(seconds: 90));
          _validate(response);
          final item = await _decode(
            Map<String, dynamic>.from(jsonDecode(response.body)['item']),
          );
          if (!_allowed(photo.spaceId)) return;
          _remote[id] = item;
          await cacheAttachment(item);
          await _outbox.record('${user.uid}/$id').delete(database!);
          _pending.remove(id);
          if (item.publishedAt != null) {
            unawaited(
              SoundFeedback.confirmed(
                SoundCue.momentShared,
                'photo/$id',
                soundIntent,
              ),
            );
          }
        } catch (e) {
          if (soundIntent != null) {
            unawaited(
              SoundFeedback.emit(SoundCue.attention, intent: soundIntent),
            );
          }
          // Retain this attachment for retry without starving later spaces.
          _error = e is StateError
              ? e.message
              : 'Upload interrupted. Your photo is kept; tap Retry sharing.';
          if (_closed) return;
        }
      }
    } finally {
      _uploading = false;
      if (!_closed) notifyListeners();
    }
  }

  @override
  Future<Uint8List> fullPhoto(MediaAttachment photo) async {
    if (!photo.cloud) return super.fullPhoto(photo);
    if (!_allowed(photo.spaceId)) {
      throw StateError('You no longer have access to this space.');
    }
    final cached = _fullCache[photo.id];
    if (cached != null) return cached;
    final bytes = (await _request({
      'action': 'download',
      'space': photo.spaceId,
      'id': photo.id,
    })).bodyBytes;
    if (_fullCache.length >= 20) {
      _fullCache.remove(_fullCache.keys.first);
    }
    _fullCache[photo.id] = bytes;
    return bytes;
  }

  @override
  Future<void> publishTask(Task supplied) async {
    final intent = SoundFeedback.captureIntent();
    final unpublished = items
        .where(
          (p) =>
              p.taskId == supplied.id &&
              p.uploaderId == user.uid &&
              p.publishedAt == null,
        )
        .map((p) => p.id)
        .toSet();
    await super.publishTask(supplied);
    if (!_allowed(supplied.spaceId)) return;
    try {
      await _request({
        'action': 'publishTask',
        'space': supplied.spaceId,
        'task': supplied.id,
      });
      _lastRefresh.remove(supplied.spaceId);
      await refresh(supplied.spaceId);
      for (final item in _remote.values.where(
        (p) =>
            unpublished.contains(p.id) &&
            p.taskId == supplied.id &&
            p.uploaderId == user.uid &&
            p.publishedAt != null,
      )) {
        unawaited(
          SoundFeedback.confirmed(
            SoundCue.momentShared,
            'photo/${item.id}',
            intent,
          ),
        );
      }
    } catch (e) {
      _error = 'Task completed. Photos will publish when sharing reconnects.';
      if (!_closed) notifyListeners();
    }
  }

  @override
  Future<void> remove(MediaAttachment supplied, String actor) async {
    if (_uploading) {
      throw StateError('Wait for the current upload before removing a photo.');
    }
    if (actor != user.uid || supplied.uploaderId != user.uid) {
      throw StateError('Only the uploader can remove this photo.');
    }
    if (supplied.cloud || _pending.contains(supplied.id)) {
      await _request({
        'action': 'delete',
        'space': supplied.spaceId,
        'id': supplied.id,
      });
    }
    await super.remove(supplied, actor);
    _remote.remove(supplied.id);
    _pending.remove(supplied.id);
    _fullCache.remove(supplied.id);
    await _outbox.record('${user.uid}/${supplied.id}').delete(database!);
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _retryTimer?.cancel();
    _client.close();
    _fullCache.clear();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
