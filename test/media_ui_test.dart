import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stewardie/app.dart';
import 'package:stewardie/core/demo_state.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/core/place_pin.dart';
import 'package:stewardie/features/media/camera_screen.dart';
import 'package:stewardie/features/media/media_library.dart';
import 'package:stewardie/features/media/photo_composer.dart';
import 'package:stewardie/features/media/photo_viewer.dart';
import 'package:stewardie/features/media/photo_reactions.dart';
import 'package:stewardie/features/moments/moments_screen.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/features/timeline/domain/models.dart';

import 'demo_ui_test.dart' show captureKey, screenshot, reveal;
import 'permissions_moments_selection_test.dart' show HeldReactions;

late Uint8List photoBytes;
late PhotoDraft photo;

class _ViewerReactions extends HeldReactions {
  @override
  Future<Uint8List> fullPhoto(MediaAttachment item) async => item.photo.bytes;
}

Future<ProviderContainer> startMedia(
  WidgetTester tester, {
  double width = 360,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 850);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(
          DemoRepository(delay: Duration.zero),
        ),
        photoPickerProvider.overrideWithValue(
          () async => CapturedPhoto(photoBytes, 'library'),
        ),
      ],
      child: RepaintBoundary(key: captureKey, child: const StewardieApp()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(StewardieApp)));
}

Future<void> waitForPhoto(WidgetTester tester) async {
  for (var i = 0; i < 100 && find.byType(TextField).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(find.byType(TextField), findsOneWidget);
}

Future<void> completionPrompt(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Make something good'),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  // Keep the target clear of the floating dock before tapping.
  await reveal(tester, find.text('Make something good'));
  await tester.tap(find.text('Make something good'));
  await tester.pumpAndSettle();
  await reveal(tester, find.text('Mark done').last);
  await tester.tap(find.text('Mark done').last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('NunitoSans')
      ..addFont(rootBundle.load('assets/fonts/nunito-sans.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final fixture = img.Image(width: 480, height: 320);
    img.fill(fixture, color: img.ColorRgb8(184, 215, 228));
    img.fillRect(
      fixture,
      x1: 0,
      y1: 200,
      x2: 479,
      y2: 319,
      color: img.ColorRgb8(236, 215, 177),
    );
    img.fillCircle(
      fixture,
      x: 350,
      y: 80,
      radius: 40,
      color: img.ColorRgb8(255, 234, 163),
    );
    photoBytes = img.encodePng(fixture);
    photo = processPhoto({'bytes': photoBytes, 'source': 'library'});
  });

  testWidgets('completion cancellation leaves task unfinished', (tester) async {
    final container = await startMedia(tester);
    await completionPrompt(tester);
    expect(find.text('Mark done without photo'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(repositoryProvider)
          .tasks
          .firstWhere((t) => t.id == 'dinner')
          .isDone,
      isFalse,
    );
    expect(container.read(mediaLibraryProvider).items, isEmpty);
  });

  testWidgets(
    'failed completion creates no upload, preserves draft, retry publishes once',
    (tester) async {
      final container = await startMedia(tester);
      await completionPrompt(tester);
      await tester.tap(find.text('Choose photo'));
      await tester.pump();
      await waitForPhoto(tester);
      await tester.enterText(find.byType(TextField), 'Made together');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      (container.read(repositoryProvider) as DemoRepository).nextOutcome =
          DemoOutcome.failure;
      await reveal(tester, find.text('Finish & share photo'));
      await tester.tap(find.text('Finish & share photo'));
      await tester.pumpAndSettle();
      expect(container.read(mediaLibraryProvider).items, isEmpty);
      expect(
        container
            .read(repositoryProvider)
            .tasks
            .firstWhere((t) => t.id == 'dinner')
            .isDone,
        isFalse,
      );
      expect(find.text('Finish & share photo'), findsOneWidget);
      await reveal(tester, find.text('Finish & share photo'));
      await tester.tap(find.text('Finish & share photo'));
      await tester.pumpAndSettle();
      expect(container.read(mediaLibraryProvider).items, hasLength(1));
      expect(
        container.read(mediaLibraryProvider).items.single.publishedAt,
        isNotNull,
      );
      expect(
        container
            .read(repositoryProvider)
            .tasks
            .firstWhere((t) => t.id == 'dinner')
            .isDone,
        isTrue,
      );
    },
  );
  testWidgets(
    'unavailable camera keeps library and close controls usable at large text',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/camera');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => <Object>[],
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: RepaintBoundary(
              key: captureKey,
              child: const CameraScreen(spaceName: 'Home crew'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('The camera could not start. Try again or choose a photo.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byTooltip('Choose photo'),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNotNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byTooltip('Take photo'),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byTooltip('Turn flash on'),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
      await screenshot(tester, 'camera-unavailable-360-2x');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saving a photo reports platform failure and permits retry', (
    tester,
  ) async {
    const channel = MethodChannel('gal');
    var fail = true;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'requestAccess') return true;
      if (fail) throw PlatformException(code: 'accessDenied');
      expect((call.arguments as Map)['bytes'], photo.bytes);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final post = MediaAttachment(
      id: 'test',
      spaceId: 'home',
      uploaderId: 'me',
      caption: '',
      createdAt: DateTime.now(),
      photo: photo,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: SoftPop.theme, home: PhotoViewer(post)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save.'), findsOneWidget);
    fail = false;
    await tester.tap(find.byTooltip('Save photo'));
    await tester.pumpAndSettle();
    expect(find.text('Saved to your photos.'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('pinned viewer fits one short page at ${scale}x', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final post = MediaAttachment(
        id: 'pinned',
        spaceId: 'home',
        uploaderId: 'me',
        caption: 'A very long caption to check the compact viewer layout and details access.',
        createdAt: DateTime.now(),
        photo: photo,
        cloud: true,
        pin: const PlacePin(
          lat: 14.6,
          lng: 121,
          label: 'A long saved location in the Philippines',
          source: 'capture',
        ),
      );
      final reactions = _ViewerReactions();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mediaLibraryProvider.overrideWithValue(reactions)],
          child: RepaintBoundary(
            key: captureKey,
            child: MaterialApp(theme: SoftPop.theme, home: PhotoViewer(post)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(PhotoReactions), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Like, 0 reactions',
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Taken here'), findsOneWidget);
      expect(find.textContaining('Taken here'), findsNothing);
      expect(tester.takeException(), isNull);
      await screenshot(tester, 'moment-page-short-${scale.toInt()}x');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final settings in [(360.0, 1.0), (430.0, 1.0), (360.0, 2.0)]) {
    testWidgets(
      'Moments TV filtering, paging and preview ${settings.$1} ${settings.$2}',
      (tester) async {
        final container = await startMedia(
          tester,
          width: settings.$1,
          scale: settings.$2,
        );
        final library = container.read(mediaLibraryProvider);
        await library.add(photo, 'home', 'me', 'A sunny afternoon');
        await library.add(photo, 'home', 'me', 'Another little moment');
        await library.add(photo, 'weekend', 'me', 'Only in weekend');
        await tester.tap(find.text('Moments'));
        await tester.pumpAndSettle();
        await reveal(tester, find.byType(ClayTelevision).first);
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(photo.bytes),
            tester.element(find.byType(ClayTelevision).first),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 of 2'), findsOneWidget);
        expect(find.text('Only in weekend'), findsNothing);
        await screenshot(
          tester,
          'moments-${settings.$1.toInt()}-${settings.$2.toInt()}x',
        );
        await reveal(tester, find.byTooltip('Next moment'));
        await tester.tap(find.byTooltip('Next moment'));
        await tester.pumpAndSettle();
        expect(find.text('2 of 2'), findsOneWidget);
        await reveal(tester, find.byType(ClayTelevision).last);
        await tester.tap(find.bySemanticsLabel('Expand photo').last);
        await tester.pumpAndSettle();
        expect(find.byType(PhotoViewer), findsOneWidget);
        expect(find.byType(InteractiveViewer), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        container.read(demoProvider.notifier).selectPerson('alex');
        await tester.pumpAndSettle();
        expect(find.byType(ClayTelevision), findsNothing);
        container.read(demoProvider.notifier).selectPerson(null);
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Add moment'));
        await tester.tap(find.text('Add moment'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose photo'));
        await tester.pump();
        await waitForPhoto(tester);
        await tester.enterText(find.byType(TextField), 'A new moment');
        tester.view.viewInsets = const FakeViewPadding(bottom: 270);
        await tester.pumpAndSettle();
        await reveal(tester, find.byType(TextField));
        await screenshot(
          tester,
          'photo-keyboard-${settings.$1.toInt()}-${settings.$2.toInt()}x',
        );
        tester.view.resetViewInsets();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await reveal(tester, find.text('Share moment'));
        await tester.tap(find.text('Share moment'));
        await tester.pumpAndSettle();
        expect(
          library.items.where((p) => p.caption == 'A new moment'),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
