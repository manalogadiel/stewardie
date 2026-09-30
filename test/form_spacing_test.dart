import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stewardie/core/demo_state.dart';
import 'package:stewardie/core/place_pin.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/features/timeline/presentation/task_widgets.dart';

class _DeniedLocation extends GeolocatorPlatform {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.deniedForever;
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('task validation clears the next label at ${scale}x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = DemoRepository(delay: Duration.zero);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: SoftPop.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showAddTask(context, repository.spaces.first),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'hhhhhhhhhhhh');
      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pumpAndSettle();
      final error = find.text('Use a clear name without repeated-key spam.');
      final label = find.text('Who is this for?');
      expect(
        tester.getRect(label).top - tester.getRect(error).bottom,
        greaterThanOrEqualTo(8),
      );
      final text = tester.widget<Text>(error);
      expect(text.maxLines, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('place fields leave room for floating labels at ${scale}x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previous = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _DeniedLocation();
      addTearDown(() => GeolocatorPlatform.instance = previous);
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPlacePicker(
                  context,
                  initial: const PlacePin(
                    lat: 14.6,
                    lng: 121,
                    label: 'Rizal Road, 4201 Bauan, Philippines',
                    note: 'Meet here',
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final sheetScroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // Move the sheet directly: a drag over the map pans its camera instead.
      sheetScroll.position.jumpTo(sheetScroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      expect(
        tester.getRect(fields.at(1)).top - tester.getRect(fields.at(0)).bottom,
        greaterThanOrEqualTo(16),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
