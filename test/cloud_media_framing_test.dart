import 'dart:async';

import 'package:image/image.dart' as img;

import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/features/media/media_library.dart';
import 'package:stewardie/features/timeline/domain/models.dart';
import 'package:stewardie/online/cloud_media_library.dart';
import 'package:stewardie/online/firebase_repository.dart';

class _FakeTimelineRepository extends Fake
    implements FirebaseTimelineRepository {
  @override
  final List<Space> spaces = const [
    Space('space-1', 'Home', 'home', [Member('user-123', 'User', 'U', 0)]),
  ];
  @override
  String get currentUserId => 'user-123';
  @override
  final Stream<void> changes = const Stream.empty();
  @override
  bool get isPlus => true;
}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'user-123';
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'fake-id-token';
}

void main() {
  test('cloud archive is paged and reuses thumbnail bytes', () async {
    final db = await databaseFactoryMemory.openDatabase('archive-pagination');
    addTearDown(db.close);
    final calls = <Map<String, dynamic>>[];
    final thumb = img.encodeJpg(img.Image(width: 10, height: 10));
    Map<String, dynamic> row(String id) => {
      'id': id,
      'space_id': 'space-1',
      'uploader_uid': 'user-123',
      'caption': 'Photo',
      'created_at': '2026-10-01T10:00:00Z',
      'published_at': '2026-10-01T10:00:00Z',
      'moment_date': '2026-10-01',
      'width': 10,
      'height': 10,
    };
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      calls.add(body);
      if (body['action'] == 'download') return http.Response.bytes(thumb, 200);
      if (body['mode'] == 'dates')
        return http.Response(
          jsonEncode({
            'dates': [
              {'date': '2026-10-01', 'count': 1, 'cover': row('same')},
            ],
            'serverTime': DateTime.now().toUtc().toIso8601String(),
          }),
          200,
        );
      return http.Response(
        jsonEncode({
          'items': [for (var i = 0; i < 31; i++) row('p$i')],
        }),
        200,
      );
    });
    final library = CloudMediaLibrary(
      _FakeTimelineRepository(),
      user: _FakeUser(),
      database: db,
      records: stringMapStoreFactory.store('paged-photos'),
      initial: [],
      pending: {},
      client: client,
    );
    addTearDown(library.dispose);
    final first = await library.archiveDates('space-1');
    await library.archiveDates('space-1');
    expect(first.items.single.count, 1);
    expect(calls.where((c) => c['action'] == 'download').length, 1);
    final day = await library.archiveDay('space-1', '2026-10-01');
    expect(day.items.length, 30);
    expect(day.cursor?['beforeId'], 'p29');
    expect(calls.where((c) => c['action'] == 'download').length, 31);
    expect(
      calls.where((c) => c['action'] == 'page').every((c) => c['limit'] <= 30),
      isTrue,
    );
    expect(calls.any((c) => c['action'] == 'list'), isFalse);
  });

  group('FramingRect robust bounds and presets', () {
    test('boundary and invalid coordinates deserialize safely', () {
      final boundary = FramingRect.fromMap({'x': 1.0, 'y': 0.0});
      expect(boundary.x, lessThanOrEqualTo(0.99));
      expect(boundary.width, greaterThan(0.0));
      expect(boundary.width + boundary.x, lessThanOrEqualTo(1.0001));

      final nanRect = FramingRect.fromMap({
        'x': double.nan,
        'y': double.infinity,
        'width': -1.0,
      });
      expect(nanRect.isFull, isTrue);
    });

    test('presets 9:16 and 16:9 calculate correct dimensions', () {
      final vertical = FramingRect.fromAspectRatio(
        targetRatio: 9.0 / 16.0,
        imageWidth: 1000,
        imageHeight: 1000,
        ratioName: '9:16',
      );
      expect(vertical.ratioName, '9:16');
      expect(
        (vertical.width / vertical.height - 9.0 / 16.0).abs(),
        lessThan(0.01),
      );

      final horizontal = FramingRect.fromAspectRatio(
        targetRatio: 16.0 / 9.0,
        imageWidth: 1000,
        imageHeight: 1000,
        ratioName: '16:9',
      );
      expect(horizontal.ratioName, '16:9');
      expect(
        (horizontal.width / horizontal.height - 16.0 / 9.0).abs(),
        lessThan(0.01),
      );
    });
  });

  group('MediaAttachment serialization', () {
    test('preserves non-destructive framing in local persistence', () {
      const framing = FramingRect(
        x: 0.1,
        y: 0.15,
        width: 0.8,
        height: 0.7,
        ratioName: 'custom',
      );
      final draft = PhotoDraft(
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([1]),
        100,
        100,
        'camera',
        framing: framing,
      );
      final attachment = MediaAttachment(
        id: 'test-1',
        spaceId: 'space-1',
        uploaderId: 'user-1',
        caption: 'Caption',
        createdAt: DateTime.utc(2026, 9, 24),
        photo: draft,
        framing: framing,
      );

      final map = attachment.toMap();
      expect(map['framing'], isNotNull);
      final restored = MediaAttachment.fromMap(map);
      expect(restored.framing.x, 0.1);
      expect(restored.framing.y, 0.15);
      expect(restored.framing.width, 0.8);
      expect(restored.framing.height, 0.7);
      expect(restored.framing.ratioName, 'custom');
      expect(restored.photo.framing.ratioName, 'custom');
    });
  });

  group('CloudMediaLibrary adapter round-trip', () {
    test(
      'upload sends baked framing and decodes legacy-safe full metadata',
      () async {
        final db = await newDatabaseFactoryMemory().openDatabase(
          'cloud-media-test',
        );
        addTearDown(db.close);

        String? capturedFramingField;

        final mockClient = MockClient.streaming((request, bodyStream) async {
          final url = request.url.toString();
          if (url.contains('action=upload')) {
            if (request is http.MultipartRequest) {
              capturedFramingField = request.fields['framing'];
            }
            final bytes = await bodyStream.toBytes();
            final bodyString = String.fromCharCodes(bytes);

            final match = RegExp(r'name="framing"[^\r\n]*\r?\n\r?\n([^\r\n]+)')
                .firstMatch(bodyString);
            if (capturedFramingField == null && match != null) {
              capturedFramingField = match.group(1);
            }

            final responseJson = jsonEncode({
              'item': {
                'id': 'photo-123',
                'space_id': 'space-1',
                'uploader_uid': 'user-123',
                'caption': 'Shared with framing',
                'created_at': DateTime.utc(2026, 9, 24).toIso8601String(),
                'width': 300,
                'height': 195,
                'state': 'ready',
                'framing': {
                  'x': 0.0,
                  'y': 0.0,
                  'width': 1.0,
                  'height': 1.0,
                  'ratioName': 'original',
                },
              },
            });
            return http.StreamedResponse(
              Stream.value(utf8.encode(responseJson)),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (url.contains('action=download')) {
            return http.StreamedResponse(
              Stream.value(Uint8List.fromList([255, 216, 255, 217])),
              200,
              headers: {'content-type': 'image/jpeg'},
            );
          }

          return http.StreamedResponse(Stream.value([]), 404);
        });

        const framing = FramingRect(
          x: 0.12,
          y: 0.18,
          width: 0.75,
          height: 0.65,
          ratioName: '3:4',
        );
        final pixels = img.encodeJpg(img.Image(width: 400, height: 300));
        final draft = PhotoDraft(
          pixels,
          pixels,
          400,
          300,
          'camera',
          framing: framing,
        );

        final cloudLib = CloudMediaLibrary(
          _FakeTimelineRepository(),
          user: _FakeUser(),
          database: db,
          records: stringMapStoreFactory.store('test-photos'),
          initial: [],
          pending: {},
          client: mockClient,
        );
        addTearDown(cloudLib.dispose);

        final attachment = await cloudLib.add(
          draft,
          'space-1',
          'user-123',
          'Shared with framing',
        );

        expect(attachment.framing.isFull, isTrue);
        expect(attachment.photo.width, 300);
        expect(attachment.photo.height, 195);
        await cloudLib.retryPending();

        expect(capturedFramingField, isNotNull);
        final parsed = jsonDecode(capturedFramingField!);
        expect(parsed['x'], 0.0);
        expect(parsed['width'], 1.0);
        expect(parsed['ratioName'], 'original');
      },
    );
  });
  test(
    'cloud add returns a durable Pending photo before the network responds',
    () async {
      final db = await databaseFactoryMemory.openDatabase('upload-pending');
      final release = Completer<void>();
      final client = MockClient((request) async {
        await release.future;
        return http.Response('{}', 503);
      });
      final library = CloudMediaLibrary(
        _FakeTimelineRepository(),
        user: _FakeUser(),
        database: db,
        records: stringMapStoreFactory.store('pending-photos'),
        initial: [],
        pending: {},
        client: client,
      );
      final pixels = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 80, height: 60)),
      );
      final photo = await library
          .add(
            PhotoDraft(pixels, pixels, 80, 60, 'camera'),
            'space-1',
            'user-123',
            'Kept for retry',
            attachmentId: 'stable-network-id',
          )
          .timeout(const Duration(seconds: 1));
      expect(photo.id, 'stable-network-id');
      expect(library.pendingIds, contains(photo.id));
      final saved = await stringMapStoreFactory
          .store(CloudMediaLibrary.outboxName)
          .record('user-123/stable-network-id')
          .get(db);
      expect(saved?['uid'], 'user-123');
      release.complete();
      await library.retryPending();
      expect(library.pendingIds, contains(photo.id));
      expect(library.syncError, isNotNull);
      final retained = library.items;
      library.dispose();
      final restartedUpload = Completer<void>();
      final restored = CloudMediaLibrary(
        _FakeTimelineRepository(),
        user: _FakeUser(),
        database: db,
        records: stringMapStoreFactory.store('pending-photos'),
        initial: retained,
        pending: {photo.id},
        client: MockClient((request) async {
          if (!restartedUpload.isCompleted) restartedUpload.complete();
          return http.Response('{}', 503);
        }),
      );
      await restartedUpload.future.timeout(const Duration(seconds: 1));
      await restored.retryPending();
      expect(restored.pendingIds, contains(photo.id));
      restored.dispose();
      await db.close();
    },
  );
  test(
    'a rejected attachment does not block the next pending upload',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'independent-uploads',
      );
      final bytes = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 80, height: 60)),
      );
      MediaAttachment photo(String id) => MediaAttachment(
        id: id,
        spaceId: 'space-1',
        uploaderId: 'user-123',
        caption: id,
        createdAt: DateTime.utc(2026, 9, 30),
        photo: PhotoDraft(bytes, bytes, 80, 60, 'camera'),
      );
      final attempted = <String>[];
      final client = MockClient.streaming((request, stream) async {
        await stream.toBytes();
        final id = (request as http.MultipartRequest).fields['id']!;
        attempted.add(id);
        if (id == 'rejected') {
          return http.StreamedResponse(
            Stream.value(utf8.encode('{"error":"Quota exceeded"}')),
            403,
          );
        }
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'item': {
                  'id': id,
                  'space_id': 'space-1',
                  'uploader_uid': 'user-123',
                  'caption': id,
                  'created_at': DateTime.utc(2026, 9, 30).toIso8601String(),
                  'width': 80,
                  'height': 60,
                },
              }),
            ),
          ),
          200,
        );
      });
      final library = CloudMediaLibrary(
        _FakeTimelineRepository(),
        user: _FakeUser(),
        database: db,
        records: stringMapStoreFactory.store('independent-photos'),
        initial: [photo('rejected'), photo('allowed')],
        pending: {'rejected', 'allowed'},
        client: client,
      );
      await library.retryPending();
      expect(attempted, ['rejected', 'allowed']);
      expect(library.pendingIds, {'rejected'});
      expect(library.items.singleWhere((p) => p.id == 'allowed').cloud, isTrue);
      expect(library.syncError, contains('Quota exceeded'));
      library.dispose();
      await db.close();
    },
  );
}
