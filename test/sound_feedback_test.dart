import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stewardie/online/online_backend.dart';
import 'package:stewardie/online/edit_outbox.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/core/sound_feedback.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/online/app_sound_settings.dart';
import 'demo_ui_test.dart' show captureKey, screenshot;

class _User extends Fake implements User {
  @override
  String get uid => 'alice';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _QueuedBackend extends Fake implements OnlineBackend {
  Completer<Map<String, dynamic>> response = Completer();
  Completer<void> started = Completer();
  @override
  FirebaseAuth get auth => _Auth();
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> values = const {},
    bool feedback = true,
  ]) {
    expect(feedback, isFalse);
    started.complete();
    return response.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stewardie/sounds');
  late Database database;
  final calls = <MethodCall>[];
  int run = 0;
  setUpAll(() async {
    disableSembastCooperator();
    await (FontLoader(
      'NunitoSans',
    )..addFont(rootBundle.load('assets/fonts/nunito-sans.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  tearDownAll(enableSembastCooperator);
  setUp(() async {
    database = await databaseFactoryMemory.openDatabase('sound-${run++}');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    SoundFeedback.foreground(true);
    await SoundFeedback.bind(database, 'alice');
    calls.clear();
  });
  tearDown(() async {
    await SoundFeedback.bind(database, null);
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  List<MethodCall> plays() => calls.where((c) => c.method == 'play').toList();

  test(
    'confirmed operations deduplicate concurrently and across restart',
    () async {
      final intent = SoundFeedback.captureIntent();
      await Future.wait([
        SoundFeedback.confirmed(SoundCue.success, 'done/1', intent),
        SoundFeedback.confirmed(SoundCue.success, 'done/1', intent),
      ]);
      expect(plays(), hasLength(1));
      expect((plays().single.arguments as Map)['gain'], .8);
      await SoundFeedback.bind(database, null);
      await SoundFeedback.bind(database, 'alice');
      await SoundFeedback.confirmed(
        SoundCue.success,
        'done/1',
        SoundFeedback.captureIntent(),
      );
      expect(plays(), hasLength(1));
    },
  );
  test('preferences persist per account, explicit opt-out stays off', () async {
    await SoundFeedback.update(const SoundSettings(enabled: false, volume: .3));
    await SoundFeedback.emit(SoundCue.saved);
    expect(plays(), isEmpty);
    await SoundFeedback.bind(database, 'bob');
    expect(SoundFeedback.settings.value.enabled, isTrue);
    expect(SoundFeedback.settings.value.volume, .8);
    await SoundFeedback.bind(database, 'alice');
    expect(SoundFeedback.settings.value.enabled, isFalse);
    expect(SoundFeedback.settings.value.volume, .3);
    SoundFeedback.clearAccount();
    expect(SoundFeedback.captureIntent(), isNull);
    expect(calls.last.method, 'stop');
  });
  test('pending opt-out survives an immediate account switch', () async {
    final save = SoundFeedback.update(
      const SoundSettings(enabled: false, volume: .2),
    );
    await SoundFeedback.bind(database, 'bob');
    await SoundFeedback.bind(database, 'alice');
    await save;
    expect(SoundFeedback.ready.value, isTrue);
    expect(SoundFeedback.settings.value.enabled, isFalse);
    expect(SoundFeedback.settings.value.volume, .2);
    await SoundFeedback.emit(SoundCue.saved);
    expect(plays(), isEmpty);
  });
  test('malformed receipt does not disable saved sound preferences', () async {
    await stringMapStoreFactory.store('app-sound-receipts').record('bad').put(
      database,
      {'account': 'alice', 'operation': 123},
    );
    await SoundFeedback.bind(database, null);
    await SoundFeedback.bind(database, 'alice');
    expect(SoundFeedback.ready.value, isTrue);
    await SoundFeedback.confirmed(
      SoundCue.saved,
      'valid-save',
      SoundFeedback.captureIntent(),
    );
    expect(plays(), hasLength(1));
  });
  test(
    'late account and background responses never chime after resuming',
    () async {
      final old = SoundFeedback.captureIntent();
      SoundFeedback.foreground(false);
      SoundFeedback.foreground(true);
      await SoundFeedback.confirmed(SoundCue.saved, 'late', old);
      final alice = SoundFeedback.captureIntent();
      await SoundFeedback.bind(database, 'bob');
      await SoundFeedback.confirmed(SoundCue.saved, 'alice', alice);
      await SoundFeedback.confirmed(SoundCue.saved, 'outbox-replay', null);
      expect(plays(), isEmpty);
      await SoundFeedback.emit(SoundCue.saved);
      expect(plays(), hasLength(1));
    },
  );
  test('reaction opt-in, cooldown, confirmation priority and notification suppression', () async {
    await SoundFeedback.emit(SoundCue.reactionPop);
    await SoundFeedback.emit(SoundCue.attention);
    expect(plays(), isEmpty);
    await SoundFeedback.update(const SoundSettings(reactions: true));
    await SoundFeedback.emit(SoundCue.reactionPop);
    await SoundFeedback.emit(SoundCue.reactionPop);
    expect(plays(), hasLength(1));
    await SoundFeedback.emit(SoundCue.success);
    await SoundFeedback.emit(SoundCue.reactionPop);
    expect(plays(), hasLength(2));
    await SoundFeedback.notificationPresented();
    await SoundFeedback.emit(SoundCue.saved);
    expect(plays(), hasLength(2));
    expect(calls.last.method, 'stop');
  });
  test(
    'unavailable playback is harmless and malformed gain is bounded',
    () async {
      expect(SoundSettings.fromMap({'volume': double.nan}).volume, .8);
      expect(SoundSettings.fromMap({'volume': 3}).volume, 1);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'unavailable'),
          );
      await SoundFeedback.confirmed(
        SoundCue.saved,
        'confirmed',
        SoundFeedback.captureIntent(),
      );
    },
  );
  test('outbox sounds only on first foreground acknowledgement; queued replay is silent', () async {
    final backend = _QueuedBackend();
    final outbox = EditOutbox(database, backend, 'alice');
    await outbox.add('save/1', 'space', 'planSave', {'operationId': 'save/1'});
    await backend.started.future;
    expect(plays(), isEmpty);
    backend.response.complete({'planId': 'plan'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(plays(), hasLength(1));
    await outbox.flush();
    expect(plays(), hasLength(1));
    outbox.close();
  });
  test('failed outbox save cannot chime success on automatic retry', () async {
    final backend = _QueuedBackend();
    final outbox = EditOutbox(database, backend, 'alice');
    await outbox.add('save/2', 'space', 'taskCreate', {
      'operationId': 'save/2',
    });
    await backend.started.future;
    backend.response.completeError(StateError('Save failed'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(plays(), isEmpty);
    backend.response = Completer();
    backend.started = Completer();
    final retry = outbox.flush(retryFailed: true);
    await backend.started.future;
    backend.response.complete({'taskId': 'task'});
    await retry;
    expect(plays(), isEmpty);
    outbox.close();
  });

  test('WAVs are reproducible, finite, smooth, mastered and mirrored', () {
    for (final cue in _soundRecipes.keys) {
      final bytes = _generateSound(cue);
      final source = File('assets/sounds/$cue.wav').readAsBytesSync();
      expect(source, orderedEquals(bytes), reason: cue);
      for (final root in [
        'android/app/src/main/res/raw',
        'ios/Runner/Sounds',
      ]) {
        expect(
          File('$root/$cue.wav').readAsBytesSync(),
          orderedEquals(source),
          reason: '$root/$cue',
        );
      }
      final data = ByteData.sublistView(bytes);
      expect(data.getUint32(24, Endian.little), 44100);
      expect(data.getUint16(22, Endian.little), 1);
      expect(data.getUint16(34, Endian.little), 16);
      final samples = [
        for (int i = 44; i < bytes.length; i += 2)
          data.getInt16(i, Endian.little) / 32767,
      ];
      expect(
        samples.every((v) => v.isFinite && v.abs() <= pow(10, -3 / 20)),
        isTrue,
      );
      expect(samples.first, 0);
      expect(samples.last, 0);
      expect(samples[1].abs(), lessThan(.001));
      expect(samples[samples.length - 2].abs(), lessThan(.001));
      final rms = sqrt(samples.fold(0.0, (s, v) => s + v * v) / samples.length);
      expect(20 * log(rms) / ln10, inInclusiveRange(-14.6, -13.9));
    }
  });
  for (final config in [(360.0, 1.0), (430.0, 1.0), (360.0, 2.0)]) {
    testWidgets('account sound controls ${config.$1} at ${config.$2}x text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(config.$1, 780);
      tester.platformDispatcher.textScaleFactorTestValue = config.$2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SoftPop.theme,
            home: const Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: AppSoundSettings(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Preview app sound'), findsOneWidget);
      await tester.tap(find.byTooltip('Preview app sound'));
      await tester.pumpAndSettle();
      expect(plays(), hasLength(1));
      await screenshot(
        tester,
        'sound-settings-${config.$1.toInt()}-${config.$2.toInt()}x',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('App sounds'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      expect(SoundFeedback.settings.value.enabled, isFalse);
    });
  }
}

const _soundRecipes = <String, (double, List<double>, double)>{
  'notification': (.70, [523.25, 659.25, 783.99], .13),
  'success': (.50, [659.25, 783.99, 1046.5], .10),
  'capture': (.20, [440, 587.33], .035),
  'saved': (.28, [523.25, 659.25], .10),
  'moment_shared': (.42, [392, 523.25, 659.25], .09),
  'space_ready': (.50, [523.25, 783.99], .17),
  'mood_checked_in': (.22, [349.23, 440], .04),
  'location_start': (.32, [440, 659.25], .11),
  'location_stop': (.28, [587.33, 392], .10),
  'reaction_pop': (.12, [523.25], .0),
  'attention': (.26, [261.63, 293.66], .10),
};

Uint8List _generateSound(String name) {
  const rate = 44100;
  final (duration, notes, spacing) = _soundRecipes[name]!;
  final count = (duration * rate).round();
  final samples = List<double>.filled(count, 0);
  final decay = duration < .35 ? 18.0 : 9.0;
  for (var i = 0; i < count; i++) {
    final t = i / rate;
    for (var n = 0; n < notes.length; n++) {
      final age = t - n * spacing;
      if (age < 0) continue;
      final attack = min(age / .012, 1.0);
      final envelope = attack * attack * exp(-age * decay);
      samples[i] +=
          (sin(2 * pi * notes[n] * age) +
              .12 * sin(2 * pi * notes[n] * 2 * age)) *
          envelope;
    }
    final fade = ((count - 1 - i) / (rate * .025)).clamp(0.0, 1.0);
    samples[i] *= fade * fade;
  }
  final peak = samples.map((v) => v.abs()).reduce(max);
  final rms = sqrt(samples.fold(0.0, (sum, v) => sum + v * v) / count);
  final gain = min(pow(10, -3 / 20) / peak, pow(10, -14 / 20) / rms);
  final data = ByteData(44 + count * 2);
  void ascii(int at, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(at + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, data.lengthInBytes - 8, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    data.setInt16(
      44 + i * 2,
      (samples[i] * gain * 32767).truncate(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}
