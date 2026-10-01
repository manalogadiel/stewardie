import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/app.dart';
import 'package:stewardie/core/demo_state.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/onboarding/screens/subscription_screen.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';

// Exports the real Flutter UI with explicit local fixture data, not a mockup.
void main() {
  testWidgets('export frame-free submission screenshot', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final font in {
      'Fredoka': 'assets/fonts/fredoka.ttf',
      'NunitoSans': 'assets/fonts/nunito-sans.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
    final key = GlobalKey();
    const capturePlus = bool.fromEnvironment('CAPTURE_ONBOARDING_PLUS');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(DemoRepository())],
        child: RepaintBoundary(
          key: key,
          child: capturePlus
              ? MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: SoftPop.theme,
                  home: Scaffold(
                    body: SafeArea(
                      child: SubscriptionScreen(
                        onExplore: () async {},
                        onContinue: () {},
                      ),
                    ),
                  ),
                )
              : const StewardieApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold).first);
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final asset in manifest.listAssets().where(
        (name) =>
            name.startsWith('assets/illustrations/') && name.endsWith('.png'),
      )) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      expect(image.width, 1179);
      expect(image.height, 2556);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('submission').create(recursive: true);
      await File(
        capturePlus
            ? 'submission/stewardie-onboarding-plus-1179x2556.png'
            : 'submission/stewardie-today-1179x2556.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  });
}
