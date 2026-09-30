import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// Original, quiet UI chimes: no external samples or licensed recordings.
void main() {
  const rate = 44100;
  final cues = {
    'notification': [523.25, 659.25, 783.99],
    'success': [659.25, 783.99, 1046.5],
    'capture': [880.0, 1174.66],
  };
  for (final cue in cues.entries) {
    final duration = cue.key == 'capture' ? .24 : .65;
    final count = (duration * rate).round();
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
      final t = i / rate;
      var sample = 0.0;
      for (var n = 0; n < cue.value.length; n++) {
        final age = t - n * (cue.key == 'capture' ? .035 : .11);
        if (age < 0) continue;
        final envelope =
            min(age / .014, 1.0) * exp(-age * (cue.key == 'capture' ? 24 : 9));
        sample += sin(2 * pi * cue.value[n] * age) * envelope * .15;
      }
      sample *= min((duration - t) / .035, 1.0);
      data.setInt16(
        44 + i * 2,
        (sample.clamp(-.65, .65) * 32767).round(),
        Endian.little,
      );
    }
    for (final folder in [
      'assets/sounds',
      'android/app/src/main/res/raw',
      'ios/Runner/Sounds',
    ]) {
      Directory(folder).createSync(recursive: true);
      File('$folder/${cue.key}.wav')
          .writeAsBytesSync(data.buffer.asUint8List());
    }
  }
}
