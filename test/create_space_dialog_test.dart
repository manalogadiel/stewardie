import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/online/online_home.dart';

void main() {
  testWidgets('Create waits for acknowledgement and returns the saved space', (
    tester,
  ) async {
    final save = Completer<String>();
    int calls = 0;
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: SoftPop.theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showDialog<String>(
                  context: context,
                  builder: (_) => CreateSpaceDialog(
                    onCreate: (values) {
                      calls++;
                      expect(values['name'], 'New family');
                      expect(values['kind'], 'family');
                      return save.future;
                    },
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New family');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(find.text('Create a space'), findsOneWidget);
    expect(selected, isNull);
    expect(calls, 1);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    save.complete('created-id');
    await tester.pumpAndSettle();
    expect(selected, 'created-id');
    expect(find.text('Create a space'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed creation retains the draft and permits retry', (
    tester,
  ) async {
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: SoftPop.theme,
        home: Scaffold(
          body: CreateSpaceDialog(
            onCreate: (_) async {
              calls++;
              throw StateError('Connection unavailable.');
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Friends');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Connection unavailable.'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
