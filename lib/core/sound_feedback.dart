import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class SoundFeedback {
  static const _channel = MethodChannel('stewardie/sounds');
  static Future<void> play(String cue) async {
    if (kIsWeb || !['capture', 'success'].contains(cue)) return;
    try {
      await _channel.invokeMethod<void>('play', cue);
    } catch (_) {
      /* Silent mode or an unsupported platform never blocks an action. */
    }
  }
}
