import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/stewardie_map.dart';

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
    expect(find.text('Satellite needs a map key'), findsOneWidget);
    expect(chosen, isNull);
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
}
