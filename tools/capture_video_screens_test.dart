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

Future<void> saveScreenshot(GlobalKey key, String targetPath) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0); // high quality 2x
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(targetPath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(png!.buffer.asUint8List());
  image.dispose();
  stdout.writeln('Saved screenshot: $targetPath (${png.lengthInBytes} bytes)');
}

void main() {
  testWidgets('export video presentation screens', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852); // standard modern mobile
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
    final repo = DemoRepository();
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: key,
          child: const StewardieApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Precache illustrations
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold).first);
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final asset in manifest.listAssets().where(
        (name) => name.startsWith('assets/illustrations/') && name.endsWith('.png'),
      )) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    await tester.pumpAndSettle();

    final outDir = 'videos/stewardie-launch/assets/screencasts';

    // 1. Capture Today Screen
    await tester.runAsync(() async {
      await saveScreenshot(key, '$outDir/screen_today.png');
    });

    // 2. Navigate to Moments Screen
    final router = container.read(routerProvider);
    router.go('/moments');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await tester.runAsync(() async {
      await saveScreenshot(key, '$outDir/screen_moments.png');
    });

    // 3. Navigate to Space Screen
    router.go('/space');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await tester.runAsync(() async {
      await saveScreenshot(key, '$outDir/screen_space.png');
    });

    // 4. Capture Onboarding / Plus Screen
    final plusKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SoftPop.theme,
        home: Scaffold(
          body: SafeArea(
            child: RepaintBoundary(
              key: plusKey,
              child: SubscriptionScreen(
                onExplore: () async {},
                onContinue: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await saveScreenshot(plusKey, '$outDir/screen_plus.png');
    });

    stdout.writeln('All app screens exported successfully!');
  });
}
