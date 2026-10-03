import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stewardie/core/place_search.dart';
import 'package:stewardie/features/media/photo_palette.dart';
import 'package:stewardie/online/member_location_pin.dart';
import 'package:stewardie/online/notification_identity.dart';

void main() {
  test('place parser rejects malformed/out-of-range fixes and preserves provider names', () {
    final places = parsePlaceResults({
      'features': [
        {
          'properties': {
            'name': 'Market',
            'formatted': 'Market, Bauan',
            'lat': 13.8,
            'lon': 121.0,
          },
        },
        {
          'properties': {'name': 'Invalid', 'lat': 91, 'lon': 121},
        },
        {
          'properties': {'name': 'Missing fix'},
        },
        {
          'properties': {'name': '', 'lat': 0, 'lon': 0},
        },
      ],
    });
    expect(places.length, 1);
    expect(places.single.name, 'Market');
    expect(places.single.address, 'Market, Bauan');
    expect(places.single.lng, 121.0);
  });
  test('map groups colocated members but keeps distant members and rejects invalid fixes', () {
    final groups = groupMemberLocations([
      {'uid': 'a', 'lat': 14.0, 'lng': 121.0},
      {'uid': 'b', 'lat': 14.00001, 'lng': 121.0},
      {'uid': 'c', 'lat': 14.001, 'lng': 121.0},
      {'uid': 'invalid', 'lat': double.nan, 'lng': 0},
    ]);
    expect(groups.map((g) => g.map((m) => m['uid']).toList()).toList(), [
      ['a', 'b'],
      ['c'],
    ]);
  });
  test('read activity never contributes to an unread badge', () {
    expect(
      unreadActivityKey('x', {'spaceId': 's', 'readAt': DateTime.now()}),
      isNull,
    );
    expect(unreadActivityKey('x', {'spaceId': 's'}), 'activity:x');
  });
  test('palette uses only supplied bytes and blends dark colors into a light canvas', () {
    final source = img.Image(width: 16, height: 16)
      ..clear(img.ColorRgb8(0, 0, 0));
    final colors = photoPalette(Uint8List.fromList(img.encodePng(source)));
    expect(colors.length, 2);
    expect(Color(colors.first).computeLuminance(), greaterThan(.2));
    expect(photoPalette(Uint8List(0)), [0xfffaf8f2, 0xfff8e7d9]);
  });
  testWidgets(
    'grouped pins fit a small holder with scaled labels and select individual members',
    (tester) async {
      Map<String, dynamic>? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Center(
                child: SizedBox(
                  width: 226,
                  height: 180,
                  child: GroupMemberLocationPin(
                    currentUid: 'a',
                    members: [
                      {'uid': 'a', 'name': 'Alex'},
                      {'uid': 'b', 'name': 'Bea'},
                      {'uid': 'c', 'name': 'Chris'},
                    ],
                    onSelected: (member) => selected = member,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Bea'));
      expect(selected?['uid'], 'b');
    },
  );
}
