import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stewardie/core/member_avatar.dart';

void main() {
  testWidgets(
    'saved photo updates all mounted copies and cache clearing removes it',
    (tester) async {
      MemberAvatar.clearCache();
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              MemberAvatar(uid: 'photo-user', name: 'Diel'),
              MemberAvatar(uid: 'photo-user', name: 'Diel'),
            ],
          ),
        ),
      );
      MemberAvatar.updateCache(
        'photo-user',
        img.encodeJpg(img.Image(width: 8, height: 8)),
      );
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(2));
      MemberAvatar.clearCache();
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('selection changes the ring, not the avatar color', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MemberAvatar(uid: 'uid-123', name: 'Ada Lovelace'),
              MemberAvatar(
                uid: 'uid-123',
                name: 'Ada Lovelace',
                selected: true,
              ),
            ],
          ),
        ),
      ),
    );
    final avatars = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .toList();
    expect(avatars[0].backgroundColor, avatars[1].backgroundColor);
  });
  test('initials use resolved names consistently', () {
    expect(MemberAvatar.initialsFor('Ada Lovelace'), 'AL');
    expect(MemberAvatar.initialsFor('  Ada   Lovelace  '), 'AL');
    expect(MemberAvatar.initialsFor('Ada'), 'A');
  });
}
