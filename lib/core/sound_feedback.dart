import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';

enum SoundCue {
  success,
  capture,
  saved,
  momentShared,
  spaceReady,
  moodCheckedIn,
  locationStart,
  locationStop,
  reactionPop,
  attention;

  String get asset => switch (this) {
    momentShared => 'moment_shared',
    spaceReady => 'space_ready',
    moodCheckedIn => 'mood_checked_in',
    locationStart => 'location_start',
    locationStop => 'location_stop',
    reactionPop => 'reaction_pop',
    _ => name,
  };
  Duration get duration => Duration(
    milliseconds: switch (this) {
      success => 500,
      capture => 200,
      saved => 280,
      momentShared => 420,
      spaceReady => 500,
      moodCheckedIn => 220,
      locationStart => 320,
      locationStop => 280,
      reactionPop => 120,
      attention => 260,
    },
  );
}

@immutable
class SoundSettings {
  const SoundSettings({
    this.enabled = true,
    this.volume = .8,
    this.reactions = false,
    this.attention = false,
  });
  final bool enabled, reactions, attention;
  final double volume;
  Map<String, Object?> toMap() => {
    'enabled': enabled,
    'volume': volume,
    'reactions': reactions,
    'attention': attention,
  };
  factory SoundSettings.fromMap(Map<String, Object?>? map) {
    final volume = map?['volume'];
    return SoundSettings(
      enabled: map?['enabled'] != false,
      volume: volume is num && volume.isFinite
          ? volume.toDouble().clamp(0, 1)
          : .8,
      reactions: map?['reactions'] == true,
      attention: map?['attention'] == true,
    );
  }
}

/// Leaving foreground or changing account invalidates a pending action intent.
class SoundIntent {
  const SoundIntent._(this.account, this.generation);
  final String account;
  final int generation;
}

abstract final class SoundFeedback {
  static const _channel = MethodChannel('stewardie/sounds');
  static final settings = ValueNotifier(const SoundSettings());
  static final ready = ValueNotifier(false);
  static final _store = stringMapStoreFactory.store('app-sounds');
  static final _receipts = stringMapStoreFactory.store('app-sound-receipts');
  static Database? _database;
  static String? _account;
  static int _generation = 0, _bindingVersion = 0;
  static bool _foreground = true;
  static final Set<String> _heard = {};
  static DateTime _busyUntil = DateTime(1970), _reactionAt = DateTime(1970);
  static DateTime _notificationUntil = DateTime(1970);
  static Future<void> _writes = Future.value();

  static Future<void> bind(Database database, String? account) async {
    if (_account == account && identical(database, _database)) return;
    ++_generation;
    final bindingVersion = ++_bindingVersion;
    _account = account;
    _database = database;
    ready.value = false;
    settings.value = const SoundSettings();
    _heard.clear();
    _busyUntil = _reactionAt = _notificationUntil = DateTime(1970);
    await _native('stop');
    if (account == null || bindingVersion != _bindingVersion) return;
    try {
      // A quick account switch must not reload preferences before a pending
      // opt-out/volume write has finished.
      await _writes;
      if (bindingVersion != _bindingVersion) return;
      final data = await _store.record(account).get(database);
      final receipts = await _receipts.find(
        database,
        finder: Finder(filter: Filter.equals('account', account)),
      );
      if (bindingVersion != _bindingVersion) return;
      settings.value = SoundSettings.fromMap(data);
      _heard.addAll(
        receipts.map((r) => r.value['operation']).whereType<String>(),
      );
      ready.value = true;
    } catch (_) {
      // Unreadable preferences stay quiet, preserving an existing opt-out.
    }
  }

  static void clearAccount() {
    final database = _database;
    if (database != null) unawaited(bind(database, null));
  }

  static SoundIntent? captureIntent() =>
      _foreground && ready.value && _account != null
      ? SoundIntent._(_account!, _generation)
      : null;
  static bool _valid(SoundIntent? intent) =>
      intent != null &&
      _foreground &&
      ready.value &&
      intent.account == _account &&
      intent.generation == _generation;

  static void foreground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _generation++;
    if (!value) unawaited(_native('stop'));
  }

  static Future<void> update(SoundSettings value) async {
    final database = _database, account = _account;
    if (database == null || account == null || !ready.value) return;
    final bindingVersion = _bindingVersion;
    final next = SoundSettings.fromMap(value.toMap());
    final write = _writes.then(
      (_) => _store.record(account).put(database, next.toMap()),
    );
    _writes = write.then<void>((_) {}, onError: (Object _) {});
    await write;
    if (bindingVersion != _bindingVersion || account != _account) return;
    settings.value = next;
    if (!next.enabled || next.volume == 0) await _native('stop');
  }

  static Future<void> confirmed(
    SoundCue cue,
    String operation,
    SoundIntent? intent,
  ) async {
    if (!_valid(intent) || !_heard.add(operation)) return;
    final database = _database!;
    try {
      await _receipts.record('${intent!.account}/$operation').put(database, {
        'account': intent.account,
        'operation': operation,
      });
      if (_valid(intent)) await emit(cue, intent: intent);
    } catch (_) {
      // Audio failures cannot change a confirmed operation.
    }
  }

  static Future<void> play(String cue) async {
    for (final value in SoundCue.values) {
      if (value.asset == cue) return emit(value);
    }
  }

  static Future<void> emit(SoundCue cue, {SoundIntent? intent}) async {
    final captured = intent ?? captureIntent();
    final prefs = settings.value;
    if (!_valid(captured) || !prefs.enabled || prefs.volume == 0 || kIsWeb)
      return;
    if (cue == SoundCue.reactionPop && !prefs.reactions) return;
    if (cue == SoundCue.attention && !prefs.attention) return;
    final now = DateTime.now();
    if (now.isBefore(_notificationUntil)) return;
    if (cue == SoundCue.reactionPop) {
      if (now.difference(_reactionAt).inMilliseconds < 200 ||
          now.isBefore(_busyUntil))
        return;
      _reactionAt = now;
    }
    _busyUntil = now.add(cue.duration);
    await _native('play', {'cue': cue.asset, 'gain': prefs.volume});
  }

  static Future<void> notificationPresented() async {
    _notificationUntil = DateTime.now().add(const Duration(milliseconds: 800));
    await _native('stop');
  }

  static Future<void> _native(String method, [Object? arguments]) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (_) {}
  }
}
