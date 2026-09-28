import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/member_avatar.dart';

void main() {
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
