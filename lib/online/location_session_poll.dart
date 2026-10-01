import 'dart:async';

/// One request at a time, with no further collection after the map is closed.
Stream<List<Map<String, dynamic>>> pollLocationSessions(
  Future<List<Map<String, dynamic>>> Function() load, {
  Duration interval = const Duration(seconds: 15),
  bool Function(Object)? stopOnError,
}) {
  late final StreamController<List<Map<String, dynamic>>> controller;
  Timer? timer;
  bool cancelled = false;
  Future<void> fetch() async {
    try {
      final sessions = await load();
      if (!cancelled) controller.add(sessions);
    } catch (error, stack) {
      if (!cancelled) {
        controller.addError(error, stack);
        if (stopOnError?.call(error) == true) {
          cancelled = true;
          unawaited(controller.close());
        }
      }
    }
    if (!cancelled) timer = Timer(interval, fetch);
  }

  controller = StreamController<List<Map<String, dynamic>>>(
    onListen: fetch,
    onCancel: () {
      cancelled = true;
      timer?.cancel();
    },
  );
  return controller.stream;
}
