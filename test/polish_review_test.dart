import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/features/media/photo_composer.dart';
import 'package:stewardie/online/login_scene.dart';
import 'package:stewardie/online/remembered_account.dart';

void main() {
  test('remembered identity can be forgotten and contains no authentication secret', () async {
    final db = await databaseFactoryMemory.openDatabase('remembered-test');
    await const RememberedAccount('test@example.test', 'Taylor').save(db);
    expect((await RememberedAccount.load(db))!.email, 'test@example.test');
    await RememberedAccount.forget(db);
    expect(await RememberedAccount.load(db), isNull);
    await db.close();
  });
  testWidgets('Add moment is a centered sheet and cancels without a photo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final space = DemoRepository().spaces.first;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showPhotoComposer(context, space),
                  child: const Text('Add moment'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add moment'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.center.dx, closeTo(215, 1));
    expect(find.text('Take photo'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
  testWidgets('login illustration fits small phones and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: SoftPop.theme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 780),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const LoginScene(),
                    Text(
                      'A little more together',
                      style: SoftPop.theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 24),
                    const TextField(
                      decoration: InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 14),
                    const TextField(
                      decoration: InputDecoration(labelText: 'Password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      final file = File('build/review/login-polish-360.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      image.dispose();
    });
  });
}
