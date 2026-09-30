import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/demo_state.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/core/task_name.dart';
import 'package:stewardie/core/stewardie_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/features/timeline/domain/models.dart';
import 'package:stewardie/features/onboarding/permission_adapter.dart';
import 'package:stewardie/features/onboarding/screens/permissions_screen.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_invitation.dart';
import 'package:stewardie/features/media/media_library.dart';
import 'package:stewardie/features/media/photo_reactions.dart';
import 'package:stewardie/online/cloud_media_library.dart';

class MutableSpaces extends DemoRepository {
  List<Space>? available;
  @override
  List<Space> get spaces => available ?? super.spaces;
}

class HeldPermission extends PermissionAdapter {
  final request = Completer<PermissionStatusState>();
  final calls = <PermissionCapability>[];
  bool granted = false;
  @override
  Future<PermissionStatusState> checkStatus(
    PermissionCapability capability,
  ) async => capability == PermissionCapability.camera && granted
      ? PermissionStatusState.granted
      : PermissionStatusState.notDetermined;
  @override
  Future<bool> locationServicesEnabled() async => true;
  @override
  Future<PermissionStatusState> requestPermission(
    PermissionCapability capability,
  ) async {
    calls.add(capability);
    final result = await request.future;
    granted = true;
    return result;
  }
}

class TestUser extends Fake implements User {
  @override
  String get uid => 'me';
}

class HeldReactions extends Fake implements CloudMediaLibrary {
  final requests = <String?>[];
  final ack = Completer<List<Map<String, dynamic>>>();
  final nextAck = Completer<List<Map<String, dynamic>>>();
  @override
  User get user => TestUser();
  @override
  Future<List<Map<String, dynamic>>> reactions(
    MediaAttachment photo, {
    String? type,
    bool change = false,
  }) async {
    if (!change) return [];
    requests.add(type);
    return requests.length == 1 ? ack.future : nextAck.future;
  }
}

void main() {
  test(
    'task names reject repeated keys but preserve short and ordinary names',
    () {
      expect(taskNameError('aaaaaa'), isNotNull);
      expect(taskNameError('Fix AAAAAA sink'), isNotNull);
      expect(taskNameError('111111'), isNotNull);
      expect(taskNameError('Go'), isNull);
      expect(taskNameError('Book a room'), isNull);
    },
  );
  testWidgets('map refresh is visible before a tile error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: StewardieMap(center: const LatLng(14.6, 121), zoom: 16),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Refresh map'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh map'));
    await tester.pump();
    expect(find.byTooltip('Refresh map'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'tour continuation remains usable on a short screen with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    TutorialInvitationSheet.show(context, resume: true),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.ensureVisible(find.text('Continue tour'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Continue tour'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    },
  );
  test('confirmed space selection survives delayed membership, then removal falls back', () {
    final repo = MutableSpaces();
    final old = repo.spaces.first;
    repo.available = [old];
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final controller = container.read(demoProvider.notifier);
    controller.switchSpace('joined');
    controller.refresh();
    expect(container.read(demoProvider).spaceId, 'joined');
    repo.available = [old, const Space('joined', 'Friends', 'friends', [])];
    controller.refresh();
    expect(container.read(demoProvider).spaceId, 'joined');
    repo.available = [old];
    controller.refresh();
    expect(container.read(demoProvider).spaceId, old.id);
  });
  testWidgets(
    'native permission prompts serialize without dimming unrelated cards',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final adapter = HeldPermission();
      Set<PermissionCapability> skipped = {};
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: PermissionsScreen(
              adapter: adapter,
              onContinue: () {},
              onSkippedChanged: (value) => skipped = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow').first);
      await tester.pump();
      final buttons = tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .toList();
      expect(buttons[0].onPressed, isNull);
      expect(buttons[1].onPressed, isNotNull);
      expect(buttons[2].onPressed, isNotNull);
      expect(buttons.last.onPressed, isNull);
      expect(
        buttons[1].style!.backgroundColor!.resolve({}),
        SoftPop.lightButter,
      );
      await tester.tap(find.text('Allow').at(1));
      expect(adapter.calls, [PermissionCapability.camera]);
      await tester.tap(find.text('Not now').at(1));
      expect(skipped, {PermissionCapability.location});
      adapter.request.complete(PermissionStatusState.granted);
      await tester.pumpAndSettle();
      expect(find.text('Allowed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reaction feedback is immediate and latest choice saves serially',
    (tester) async {
      final library = HeldReactions();
      final photo = MediaAttachment(
        id: 'p',
        spaceId: 'home',
        uploaderId: 'other',
        caption: '',
        createdAt: DateTime(2026),
        cloud: true,
        photo: PhotoDraft(Uint8List(0), Uint8List(0), 1, 1, 'camera'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mediaLibraryProvider.overrideWithValue(library)],
          child: MaterialApp(
            theme: SoftPop.theme,
            home: Scaffold(body: PhotoReactions(photo: photo)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder reaction(String label) => find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label?.startsWith('$label,') == true,
      );
      await tester.tap(reaction('Like'));
      await tester.pump();
      expect(
        find.descendant(of: reaction('Like'), matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.text('Like'), findsNothing);
      await tester.tap(reaction('Heart'));
      await tester.pump();
      expect(library.requests, ['like']);
      expect(
        find.descendant(of: reaction('Heart'), matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: reaction('Like'), matching: find.text('0')),
        findsOneWidget,
      );
      library.ack.complete([
        {'uid': 'me', 'type': 'like'},
      ]);
      await tester.pump();
      expect(library.requests, ['like', 'heart']);
      library.nextAck.completeError(StateError('Network unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: reaction('Like'), matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: reaction('Heart'), matching: find.text('0')),
        findsOneWidget,
      );
      expect(find.text('Could not save your reaction. Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
