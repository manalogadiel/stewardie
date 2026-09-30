import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stewardie/core/month_year_picker.dart';
import 'package:stewardie/core/profile_photo.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/subscription/soft_pop_paywall.dart';
import 'package:stewardie/online/rename_space_dialog.dart';
import 'package:stewardie/online/member_location_pin.dart';
import 'package:stewardie/features/media/camera_screen.dart';

import 'demo_ui_test.dart' show captureKey, screenshot;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'NunitoSans': 'assets/fonts/nunito-sans.ttf',
      'Fredoka': 'assets/fonts/fredoka.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  Future<void> host(
    WidgetTester tester,
    Widget Function(BuildContext) content, {
    double width = 360,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: SoftPop.theme,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(body: Builder(builder: content)),
        ),
      ),
    );
  }

  testWidgets('rename dismissals return no name through exit animations', (
    tester,
  ) async {
    final results = <String?>[];
    await host(
      tester,
      (context) => TextButton(
        onPressed: () async =>
            results.add(await showRenameSpaceDialog(context, 'Home')),
        child: const Text('Rename'),
      ),
    );
    for (final dismissal in ['Cancel', 'barrier', 'back']) {
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Unsubmitted name');
      if (dismissal == 'Cancel') {
        await tester.tap(find.text('Cancel'));
      } else if (dismissal == 'barrier') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
    }
    expect(results, [null, null, null]);
  });

  testWidgets(
    'avatar confirmation shows full photo and saves the explicit crop',
    (tester) async {
      final image = img.Image(width: 180, height: 320);
      img.fill(image, color: img.ColorRgb8(169, 205, 232));
      String? selected;
      await host(
        tester,
        (context) => TextButton(
          onPressed: () async => selected = await ProfilePhoto.confirm(
            context,
            img.encodePng(image),
          ),
          child: const Text('Photo'),
        ),
        scale: 2,
      );
      await tester.tap(find.text('Photo'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(find.byType(Image).first).image,
          tester.element(find.byType(Image).first),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Image>(find.byType(Image).first).fit,
        BoxFit.contain,
      );
      expect(find.byType(Slider), findsOneWidget);
      await screenshot(tester, 'profile-confirmation-360-2x');
      await tester.tap(find.text('Use photo'));
      await tester.pumpAndSettle();
      final saved = img.decodeImage(base64Decode(selected!))!;
      expect(saved.width, 256);
      expect(saved.height, 256);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('month selector chooses month and year at enlarged text', (
    tester,
  ) async {
    DateTime? chosen;
    await host(
      tester,
      (_) => MonthYearButton(
        month: DateTime(2026, 9),
        onSelected: (value) => chosen = value,
      ),
      scale: 2,
    );
    await tester.tap(find.byType(MonthYearButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2027'),
      60,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await screenshot(tester, 'calendar-year-menu-360-2x');
    await tester.tap(find.text('2027').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Feb'));
    await tester.tap(find.text('Feb'));
    await screenshot(tester, 'calendar-month-year-360-2x');
    await tester.ensureVisible(find.text('Show month'));
    await tester.tap(find.text('Show month'));
    await tester.pumpAndSettle();
    expect(chosen, DateTime(2027, 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('benefits sheet expands and keeps its list scrollable', (
    tester,
  ) async {
    await host(
      tester,
      (context) => TextButton(
        onPressed: () => showSoftPopPaywall(context),
        child: const Text('Benefits'),
      ),
      width: 430,
      scale: 1.5,
    );
    await tester.tap(find.text('Benefits'));
    await tester.pumpAndSettle();
    final sheet = find.byType(DraggableScrollableSheet);
    final before = tester.getSize(sheet).height;
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(sheet).height, greaterThan(before));
    await screenshot(tester, 'plus-benefits-expanded-430');
    expect(tester.takeException(), isNull);
  });
  testWidgets('selected map pin fits its scaled name and selection ring', (
    tester,
  ) async {
    await host(
      tester,
      (context) => Center(
        child: SizedBox.fromSize(
          size: MemberLocationPin.sizeFor(context),
          child: const MemberLocationPin(
            uid: 'member-1',
            name: 'Alexandria Montgomery',
            label: 'Alexandria Montgomery',
            selected: true,
            isMe: false,
          ),
        ),
      ),
      scale: 3,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await screenshot(tester, 'map-member-pin-360-3x');
  });

  testWidgets(
    'camera recovery remains scrollable in landscape with enlarged text',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/camera');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => <Object>[],
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await host(
        tester,
        (_) => const CameraScreen(spaceName: 'Family'),
        width: 640,
        height: 360,
        scale: 2,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Choose photo'), findsOneWidget);
      await screenshot(tester, 'camera-recovery-landscape-2x');
    },
  );
}
