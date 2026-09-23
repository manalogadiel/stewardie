import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/demo_state.dart';
import 'package:stewardie/core/person_labels.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/features/timeline/domain/models.dart';

import 'demo_ui_test.dart' show start, screenshot, reveal;

void main() {
  setUpAll(() async {
    final loader = FontLoader('NunitoSans')
      ..addFont(rootBundle.load('assets/fonts/nunito-sans.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  testWidgets('floating controls leave a scrollable transparent gap', (
    tester,
  ) async {
    await start(tester, size: const Size(360, 780));
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final before = scroll.pixels;
    await tester.dragFrom(const Offset(18, 52), const Offset(18, -240));
    await tester.pumpAndSettle();
    expect(scroll.pixels, greaterThan(before));
    expect(find.text('Home crew'), findsOneWidget);
    expect(find.byTooltip('Inbox'), findsOneWidget);
    await screenshot(tester, 'floating-header-scrolled');
    await tester.tap(find.text('Home crew'));
    await tester.pumpAndSettle();
    expect(find.text('Your spaces'), findsOneWidget);
  });

  testWidgets(
    'calendar and mood subjects follow the person filter without changing identity',
    (tester) async {
      final container = await start(tester, size: const Size(430, 932));
      expect(find.text('Shared calendar'), findsOneWidget);
      expect(find.text('Your mood'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Alex'));
      await tester.pumpAndSettle();
      expect(container.read(demoProvider).personId, 'alex');
      expect(find.text('Alex’s'), findsAtLeastNWidgets(2));
      expect(find.text('Shared calendar'), findsNothing);
      expect(find.text('Calm'), findsOneWidget);
      expect(find.text('View mood'), findsOneWidget);
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/illustrations/mood-rose-calm.png'),
          tester.element(find.byType(Scaffold).first),
        ),
      );
      await tester.pumpAndSettle();
      await screenshot(tester, 'alex-mood');
      await tester.tap(find.text('View mood'));
      await tester.pumpAndSettle();
      expect(find.text('Taking a quiet moment.'), findsOneWidget);
      expect(find.textContaining('Rose ·'), findsOneWidget);
      expect(find.text('Update check-in'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await reveal(tester, find.widgetWithText(FilterChip, 'Jo'));
      await tester.tap(find.widgetWithText(FilterChip, 'Jo'));
      await tester.pumpAndSettle();
      expect(find.text('Jo’s'), findsAtLeastNWidgets(2));
      expect(find.text('No check-in yet'), findsOneWidget);
      expect(find.text('Check in'), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Me'));
      await tester.pumpAndSettle();
      expect(find.text('Your calendar'), findsOneWidget);
      expect(find.text('Your mood'), findsOneWidget);
      expect(find.text('Check in'), findsOneWidget);
    },
  );

  testWidgets(
    'mood color is independent, editable by me and cancelled drafts do not save',
    (tester) async {
      final container = await start(tester);
      final repo = container.read(repositoryProvider);
      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Happy'));
      await reveal(tester, find.text('Butter'));
      await tester.tap(find.text('Butter'));
      await reveal(tester, find.text('Share check-in'));
      await tester.runAsync(
        () => Future.wait([
          for (final mood in Mood.values)
            precacheImage(
              AssetImage('assets/illustrations/mood-butter-${mood.name}.png'),
              tester.element(find.byType(Scaffold).first),
            ),
        ]),
      );
      await tester.pumpAndSettle();
      await screenshot(tester, 'mood-butter-composer');
      await tester.tap(find.text('Share check-in'));
      await tester.pumpAndSettle();
      expect(repo.checkIn('home', 'me')?.mood, Mood.happy);
      expect(repo.checkIn('home', 'me')?.color, MoodColor.butter);
      await tester.tap(find.text('Update mood'));
      await tester.pumpAndSettle();
      final butter = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Butter'),
      );
      expect(butter.selected, isTrue);
      final roseChoice = find.widgetWithText(ChoiceChip, 'Rose');
      await reveal(tester, roseChoice);
      await tester.tap(roseChoice);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(roseChoice).selected, isTrue);
      await reveal(tester, find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.checkIn('home', 'me')?.color, MoodColor.butter);
      await tester.tap(find.text('Update mood'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Remove my check-in'));
      await tester.tap(find.text('Remove my check-in'));
      await tester.pumpAndSettle();
      expect(repo.checkIn('home', 'me'), isNull);
      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sky'))
            .selected,
        isTrue,
      );
    },
  );

  testWidgets(
    'long given name ellipsizes while calendar noun remains visible',
    (tester) async {
      const space = Space('long', 'A long space', 'Friends', [
        Member('long', 'AlexandriaAlexandriaAlexandria Santos', 'AS', 0),
      ]);
      tester.view.physicalSize = const Size(300, 500);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 170,
              child: CompactPersonTitle(
                space: space,
                personId: 'long',
                noun: 'calendar',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('calendar'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.text('AlexandriaAlexandriaAlexandria’s'))
            .overflow,
        TextOverflow.ellipsis,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('floating selector clears Today title at 200% text', (
    tester,
  ) async {
    await start(tester, size: const Size(360, 800), scale: 2);
    final selectorBottom = tester.getBottomLeft(find.text('Home crew')).dy;
    final titleTop = tester.getTopLeft(find.text('Today').first).dy;
    expect(titleTop, greaterThan(selectorBottom));
    await screenshot(tester, 'floating-header-large-text');
  });

  test('fixed local identity cannot edit another member check-in', () {
    final repo = DemoRepository(delay: Duration.zero);
    expect(
      () => repo.shareCheckIn('home', 'alex', Mood.sad, ''),
      throwsA(isA<DemoException>()),
    );
    expect(
      () => repo.removeCheckIn('home', 'alex'),
      throwsA(isA<DemoException>()),
    );
    expect(repo.checkIn('home', 'alex')?.mood, Mood.calm);
  });
}
