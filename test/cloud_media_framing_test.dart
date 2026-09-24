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

class _FakeTimelineRepository extends Fake implements FirebaseTimelineRepository {
  @override
  final List<Space> spaces = const [
    Space(
      'space-1',
      'Home',
      'home',
      [Member('user-123', 'User', 'U', 0)],
    ),
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
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'fake-id-token';
}

void main() {
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
      expect((vertical.width / vertical.height - 9.0 / 16.0).abs(), lessThan(0.01));

      final horizontal = FramingRect.fromAspectRatio(
        targetRatio: 16.0 / 9.0,
        imageWidth: 1000,
        imageHeight: 1000,
        ratioName: '16:9',
      );
      expect(horizontal.ratioName, '16:9');
      expect((horizontal.width / horizontal.height - 16.0 / 9.0).abs(), lessThan(0.01));
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
    test('upload sends framing in multipart request and decodes returned framing', () async {
      final db = await newDatabaseFactoryMemory().openDatabase('cloud-media-test');
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

          final match = RegExp(r'name="framing"[^\r\n]*\r?\n\r?\n([^\r\n]+)').firstMatch(bodyString);
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
              'width': 400,
              'height': 300,
              'state': 'ready',
              'framing': {
                'x': 0.12,
                'y': 0.18,
                'width': 0.75,
                'height': 0.65,
                'ratioName': '3:4',
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
      final draft = PhotoDraft(
        Uint8List.fromList([255, 216, 255, 217]),
        Uint8List.fromList([255, 216, 255, 217]),
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

      expect(attachment.framing.x, 0.12);
      expect(attachment.framing.ratioName, '3:4');

      expect(capturedFramingField, isNotNull);
      final parsed = jsonDecode(capturedFramingField!);
      expect(parsed['x'], 0.12);
      expect(parsed['ratioName'], '3:4');
    });
  });
}
