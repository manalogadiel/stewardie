import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/stewardie_map.dart';
import 'package:stewardie/core/place_pin.dart';

void main() {
  testWidgets('one Layers button opens map styles without changing the map', (
    tester,
  ) async {
    StewardieMapStyle? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MapLayersButton(
              selected: StewardieMapStyle.streets,
              onSelected: (style) => chosen = style,
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.layers_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.layers_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Streets'), findsOneWidget);
    expect(find.text('Satellite hybrid'), findsOneWidget);
    expect(chosen, isNull);
    await tester.tap(find.text('Satellite hybrid'));
    await tester.pumpAndSettle();
    expect(chosen, StewardieMapStyle.hybrid);
    await tester.tap(find.byIcon(Icons.layers_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Streets'));
    await tester.pump();
    expect(chosen, StewardieMapStyle.streets);
  });

  testWidgets('Layers menu fits a narrow enlarged-text screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Center(
              child: MapLayersButton(
                selected: StewardieMapStyle.streets,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.layers_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Streets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('place picker remains scrollable when the keyboard opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPlacePicker(context),
              child: const Text('Choose a place'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose a place'));
    await tester.pump(const Duration(milliseconds: 250));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.scrollUntilVisible(
      find.text('Use this place'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Use this place'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
