import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final files = [
    'onboarding - attentive.png',
    'onboarding sky key.png',
    'onboarding - email verification.png',
    'onboarding - make it yours.png',
    'onboarding - done.png',
  ];

  for (final name in files) {
    final file = File('assets/illustrations/$name');
    final im = img.decodeImage(file.readAsBytesSync())!;

    // Composite over cream #FAF9F6
    final cream = img.Image(width: im.width, height: im.height);
    img.fill(cream, color: img.ColorRgb8(250, 249, 246));
    img.compositeImage(cream, im);

    // Save a 300x300 crop of a high-contrast boundary
    // Find a boundary pixel with bright edge
    int bx = im.width ~/ 2, by = im.height ~/ 2;
    for (int y = 0; y < im.height; y++) {
      for (int x = 0; x < im.width; x++) {
        final p = im.getPixel(x, y);
        if (p.a > 30 && p.a < 200 && p.r > 220 && p.g > 220 && p.b > 220) {
          bx = x;
          by = y;
          break;
        }
      }
    }

    final cropX = (bx - 100).clamp(0, im.width - 200);
    final cropY = (by - 100).clamp(0, im.height - 200);
    final cropped = img.copyCrop(cream, x: cropX, y: cropY, width: 200, height: 200);
    File('tool/crop_${name.replaceAll(' ', '_')}').writeAsBytesSync(img.encodePng(cropped));
    print('Generated crop for $name at ($cropX, $cropY)');
  }
}
