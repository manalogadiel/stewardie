import 'dart:async';

import 'package:flutter/services.dart';

const deviceOrientationChannel = EventChannel('stewardie/device_orientation');

/// Physical rotation stays independent of the app's portrait layout. Older
/// native builds without the bridge quietly fall back to camera orientation.
Stream<double> physicalControlTurns() {
  const method = MethodChannel('stewardie/device_orientation');
  const codec = StandardMethodCodec();
  final messenger = ServicesBinding.instance.defaultBinaryMessenger;
  late StreamController<double> stream;
  stream = StreamController<double>(
    onListen: () async {
      messenger.setMessageHandler(method.name, (data) async {
        if (data == null) {
          await stream.close();
          return null;
        }
        try {
          final value = codec.decodeEnvelope(data);
          if (value is num && value.isFinite && !stream.isClosed) {
            stream.add(value.toDouble());
          }
        } catch (_) {
          /* Retain the last honest orientation. */
        }
        return null;
      });
      try {
        await method.invokeMethod<void>('listen');
      } catch (_) {
        messenger.setMessageHandler(method.name, null);
        await stream.close();
      }
    },
    onCancel: () async {
      messenger.setMessageHandler(method.name, null);
      try {
        await method.invokeMethod<void>('cancel');
      } catch (_) {}
    },
  );
  return stream.stream;
}
