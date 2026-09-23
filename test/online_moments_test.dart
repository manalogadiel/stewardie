import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/features/media/media_library.dart';
import 'package:stewardie/online/online_moments.dart';

void main() {
  test(
    'device moments reload and stay scoped to the account and space',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'online-moments-test',
      );
      addTearDown(db.close);
      final store = await OnlineMomentsStore.fromDatabase(db);
      final draft = PhotoDraft(
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([4, 5]),
        1,
        1,
        'library',
      );
      await store.add('alice', 'home1234', draft, 'A little walk');
      await store.add('alice', 'other1234', draft, 'Another space');
      await store.add('bob', 'home1234', draft, 'Another account');

      final restored = await OnlineMomentsStore.fromDatabase(db);
      final own = restored.forSpace('alice', 'home1234');
      expect(own, hasLength(1));
      expect(own.single.caption, 'A little walk');
      expect(restored.forSpace('alice', 'other1234'), hasLength(1));
      expect(restored.forSpace('bob', 'home1234'), hasLength(1));
      await expectLater(restored.remove(own.single, 'bob'), throwsStateError);
      await restored.remove(own.single, 'alice');
      expect(restored.forSpace('alice', 'home1234'), isEmpty);
      expect(restored.forSpace('bob', 'home1234'), hasLength(1));
    },
  );
}
