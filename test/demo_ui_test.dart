import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/app.dart';
import 'package:stewardie/core/demo_state.dart';
import 'package:stewardie/features/calendar/calendar_state.dart';
import 'package:stewardie/features/calendar/calendar_view.dart';
import 'package:stewardie/features/moods/mood_sheet.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/features/timeline/domain/models.dart';

final captureKey = GlobalKey();
const capture = bool.fromEnvironment('CAPTURE_DEMO');

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .2);
  await tester.pumpAndSettle();
}

Future<void> screenshot(WidgetTester tester, String name) async {
  if (!capture) {
    return;
  }
  final boundary =
      captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/review');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<ProviderContainer> start(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(DemoRepository())],
      child: RepaintBoundary(key: captureKey, child: const StewardieApp()),
    ),
  );
  await tester.pumpAndSettle();
  // Image decoding uses real asynchronous work; wait before visual captures.
  final imageContext = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(
    () => Future.wait([
      for (final name in [
        'greeting',
        'mood',
        'calendar',
        'celebrate',
        'mood-happy',
        'mood-tired',
        'mood-overwhelmed',
        'mood-sad',
        'mood-excited',
      ])
        precacheImage(
          AssetImage('assets/illustrations/$name.png'),
          imageContext,
        ),
    ]),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(StewardieApp)));
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
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  testWidgets('person filter survives back and clears on space switch', (
    tester,
  ) async {
    final container = await start(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Me'));
    await tester.pumpAndSettle();
    expect(container.read(demoProvider).personId, 'me');
    expect(find.text('Pick up a few supplies'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Make something good'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Make something good'), findsOneWidget);
    await reveal(tester, find.text('Make something good'));
    await screenshot(tester, 'today-me');
    await tester.tap(find.text('Make something good'));
    await tester.pumpAndSettle();
    await screenshot(tester, 'task-detail');
    await tester.tap(find.byTooltip('Back to Today'));
    await tester.pumpAndSettle();
    expect(container.read(demoProvider).personId, 'me');
    await tester.tap(find.text('Home crew'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekend wandering crew'));
    await tester.pumpAndSettle();
    expect(container.read(demoProvider).personId, isNull);
    expect(find.text('A little breathing room'), findsOneWidget);
    expect(find.text('Make something good'), findsNothing);
    await screenshot(tester, 'empty-space');
  });

  testWidgets(
    'calendar filters, navigates months and creates/edits/removes own plans',
    (tester) async {
      final container = await start(tester);
      await tester.tap(find.text('Shared calendar'));
      await tester.pumpAndSettle();
      final now = container.read(calendarProvider).month;
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(
        container.read(calendarProvider).month,
        DateTime(now.year, now.month + 1),
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Alex').last);
      await tester.pumpAndSettle();
      expect(container.read(demoProvider).personId, 'alex');
      expect(
        container.read(calendarProvider).month,
        DateTime(now.year, now.month + 1),
      );
      await reveal(tester, find.text('Add my plan'));
      await tester.tap(find.text('Add my plan'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Picnic by the river',
      );
      await tester.tap(find.byType(SwitchListTile));
      await reveal(tester, find.widgetWithText(CheckboxListTile, 'Alex'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Alex'));
      await reveal(tester, find.text('Save plan'));
      await screenshot(tester, 'calendar-editor');
      await tester.tap(find.text('Save plan'));
      await tester.pumpAndSettle();
      final plan = container
          .read(calendarRepositoryProvider)
          .plans
          .firstWhere((p) => p.title == 'Picnic by the river');
      expect(plan.ownerId, 'me');
      expect(plan.allDay, isTrue);
      expect(plan.participants, contains('alex'));
      await reveal(tester, find.text('Picnic by the river'));
      await tester.tap(find.text('Picnic by the river'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit plan'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Bring a picnic',
      );
      await reveal(tester, find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Bring a picnic'));
      await tester.tap(find.text('Bring a picnic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(calendarRepositoryProvider)
            .plans
            .any((p) => p.id == plan.id),
        isFalse,
      );
    },
  );

  testWidgets('pending completion, failure, retry and no photo requirement', (
    tester,
  ) async {
    final container = await start(tester);
    final repo = container.read(repositoryProvider) as DemoRepository;
    container.read(routerProvider).push('/task/dinner');
    await tester.pumpAndSettle();
    repo.nextOutcome = DemoOutcome.failure;
    await reveal(tester, find.text('Mark done'));
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark done without photo'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Saving…'), findsOneWidget);
    expect(
      repo.tasks.firstWhere((task) => task.id == 'dinner').isDone,
      isFalse,
    );
    await screenshot(tester, 'task-pending');
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save. Nothing changed. Try again.'),
      findsOneWidget,
    );
    await screenshot(tester, 'task-failure');
    await reveal(tester, find.text('Mark done'));
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark done without photo'));
    await tester.pumpAndSettle();
    expect(repo.tasks.firstWhere((task) => task.id == 'dinner').isDone, isTrue);
    expect(
      find.text('One less thing to think about. Nicely done.'),
      findsOneWidget,
    );
  });

  testWidgets('check-in can be skipped, shared, updated and removed', (
    tester,
  ) async {
    final container = await start(tester);
    final repo = container.read(repositoryProvider);
    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Skip for now'));
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(repo.checkIn('home', 'me'), isNull);
    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Taking it slow.');
    await reveal(tester, find.text('Share check-in'));
    await screenshot(tester, 'mood-audience');
    await tester.tap(find.text('Share check-in'));
    await tester.pumpAndSettle();
    expect(repo.checkIn('home', 'me')?.mood, Mood.calm);
    expect(repo.checkIn('weekend', 'me'), isNull);
    await tester.tap(find.text('Update mood'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Happy'));
    await reveal(tester, find.text('Update check-in'));
    await tester.tap(find.text('Update check-in'));
    await tester.pumpAndSettle();
    expect(repo.checkIn('home', 'me')?.mood, Mood.happy);
    await tester.tap(find.text('Update mood'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Remove my check-in'));
    await tester.tap(find.text('Remove my check-in'));
    await tester.pumpAndSettle();
    expect(repo.checkIn('home', 'me'), isNull);
  });

  for (final config in [
    (360.0, 780.0, 1.0),
    (430.0, 932.0, 1.0),
    (360.0, 800.0, 2.0),
    (780.0, 360.0, 1.0),
  ]) {
    testWidgets(
      'render ${config.$1} x ${config.$2} at ${config.$3} text scale',
      (tester) async {
        final container = await start(
          tester,
          size: Size(config.$1, config.$2),
          scale: config.$3,
        );
        final name =
            '${config.$1.toInt()}-${config.$2.toInt()}-${config.$3.toInt()}x';
        expect(tester.takeException(), isNull);
        await screenshot(tester, 'today-$name');
        final nav = container
            .read(routerProvider)
            .routerDelegate
            .navigatorKey
            .currentContext!;
        showCalendar(nav, container.read(repositoryProvider).spaces.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await screenshot(tester, 'calendar-$name');
        await tester.tap(find.byTooltip('Close calendar'));
        await tester.pumpAndSettle();
        // Reduced motion keeps the same state; no decorative animation is required.
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        container.read(routerProvider).push('/task/groceries');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await screenshot(tester, 'detail-$name');
        container.read(routerProvider).pop();
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Check in'));
        await tester.tap(find.text('Check in'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await screenshot(tester, 'mood-$name');
        await reveal(tester, find.text('Skip for now'));
        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('small mood sheet supports large text, keyboard and safe areas', (
    tester,
  ) async {
    final container = await start(tester, size: const Size(360, 800), scale: 2);
    final context = tester.element(find.byType(StewardieApp));
    final navigatorContext = container
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext!;
    showMoodSheet(
      navigatorContext,
      container.read(repositoryProvider).spaces.first,
    );
    await tester.pumpAndSettle();
    expect(context.mounted, isTrue);
    await screenshot(tester, 'mood-large-text');
    await reveal(tester, find.byType(TextField));
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetPadding);
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(TextField));
    await screenshot(tester, 'mood-keyboard');
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Skip for now'));
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
  });

  testWidgets('tabs and local task creation remain usable', (tester) async {
    final container = await start(tester);
    await tester.tap(find.text('Moments'));
    await tester.pumpAndSettle();
    expect(find.text('Room for the good bits'), findsOneWidget);
    await screenshot(tester, 'moments-preview');
    await tester.tap(find.text('Space'));
    await tester.pumpAndSettle();
    expect(find.text('Jamie (you)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await screenshot(tester, 'space-members');
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byTooltip('Add task'));
    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();
    expect(find.text('Give your task a name.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Set the table');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();
    final task = container
        .read(repositoryProvider)
        .tasks
        .firstWhere((task) => task.title == 'Set the table');
    expect(task.spaceId, 'home');
    expect(task.ownerId, isNull);
    expect(task.requestedId, 'me');
    expect(task.status, Responsibility.requested);
    container.read(routerProvider).push('/task/${task.id}');
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Accept task'));
    await tester.tap(find.text('Accept task'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(repositoryProvider)
          .tasks
          .firstWhere((t) => t.id == task.id)
          .status,
      Responsibility.accepted,
    );
  });

  testWidgets('an overdue task completed today remains in Today', (
    tester,
  ) async {
    final container = await start(tester);
    container.read(routerProvider).push('/task/recycling');
    await tester.pumpAndSettle();
    await reveal(tester, find.text('I’ve got it'));
    await tester.tap(find.text('I’ve got it'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Mark done'));
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark done without photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to Today'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Done (2)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Done (2)'));
    await tester.pumpAndSettle();
    await screenshot(tester, 'tasks-done');
    expect(find.text('Take out the recycling'), findsOneWidget);
  });

  testWidgets(
    'visible controls have screen-reader labels and adequate targets',
    (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester, size: const Size(430, 932));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Sharing with Home crew'));
      // Check the audience label regression directly. The broad screenshot
      // heuristic samples antialiased edges of the 14px variable font; the
      // actual foreground/background pairs are measured separately below.
      await expectLater(
        tester,
        meetsGuideline(
          CustomMinimumContrastGuideline(
            finder: find.text('Sharing with Home crew'),
          ),
        ),
      );
      await reveal(tester, find.text('Skip for now'));
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shared calendar'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      final dateLabel = MaterialLocalizations.of(
        tester.element(find.byType(CalendarSheet)),
      ).formatFullDate(DateTime.now());
      final day = find.bySemanticsLabel(RegExp('^$dateLabel, .* plans'));
      expect(
        tester
            .getSemantics(day)
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      handle.dispose();
    },
  );

  testWidgets(
    'calendar editor supports large text, keyboard and cancellation',
    (tester) async {
      final container = await start(
        tester,
        size: const Size(360, 800),
        scale: 2,
      );
      final nav = container
          .read(routerProvider)
          .routerDelegate
          .navigatorKey
          .currentContext!;
      showPlanEditor(
        nav,
        container.read(repositoryProvider).spaces.first,
        DateTime.now(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextFormField).first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetPadding);
      await tester.pumpAndSettle();
      await reveal(tester, find.byType(TextFormField).first);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Time to unwind',
      );
      await tester.pumpAndSettle();
      await screenshot(tester, 'calendar-keyboard');
      await reveal(tester, find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(calendarRepositoryProvider)
            .plans
            .any((p) => p.title == 'Time to unwind'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
