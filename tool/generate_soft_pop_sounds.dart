import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// Original deterministic warm bell/clay cues; no external recordings.
const soundRecipes = <String, (double, List<double>, double)>{
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

Uint8List generateSound(String name) {
  const rate = 44100;
  final (duration, notes, spacing) = soundRecipes[name]!;
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
  // RMS matching is preparation, not a claim of perceived loudness parity.
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

void main() {
  for (final name in soundRecipes.keys) {
    final bytes = generateSound(name);
    final data = ByteData.sublistView(bytes);
    var peak = 0.0, squares = 0.0;
    for (var at = 44; at < bytes.length; at += 2) {
      final sample = data.getInt16(at, Endian.little) / 32767;
      peak = max(peak, sample.abs());
      squares += sample * sample;
    }
    final rms = sqrt(squares / ((bytes.length - 44) / 2));
    stdout.writeln(
      '$name: peak ${(20 * log(peak) / ln10).toStringAsFixed(2)} dBFS; RMS ${(20 * log(rms) / ln10).toStringAsFixed(2)} dBFS',
    );
    for (final folder in [
      'assets/sounds',
      'android/app/src/main/res/raw',
      'ios/Runner/Sounds',
    ]) {
      Directory(folder).createSync(recursive: true);
      File('$folder/$name.wav').writeAsBytesSync(bytes);
    }
  }
}
