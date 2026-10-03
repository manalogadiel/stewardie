import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Only the existing thumbnail is sampled; no extra cloud request or upload.
List<int> photoPalette(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return [0xfffaf8f2, 0xfff8e7d9];
  final colors = <int>[];
  for (final top in [true, false]) {
    var r = 0, g = 0, b = 0, n = 0;
    final start = top ? 0 : image.height ~/ 2;
    final end = top ? image.height ~/ 2 : image.height;
    for (var y = start; y < end; y += 8) {
      for (var x = 0; x < image.width; x += 8) {
        final p = image.getPixel(x, y);
        r += p.r.toInt();
        g += p.g.toInt();
        b += p.b.toInt();
        n++;
      }
    }
    if (n == 0) {
      colors.add(0xfffaf8f2);
      continue;
    }
    // Cream blend keeps even dark photos within Stewardie's light clay palette.
    int blend(int value, int cream) => (value / n * .45 + cream * .55).round();
    colors.add(
      0xff000000 | (blend(r, 250) << 16) | (blend(g, 248) << 8) | blend(b, 242),
    );
  }
  return colors;
}
