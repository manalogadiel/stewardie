import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final files = [
    'onboarding-butter-welcome.png',
    'onboarding-mint-attentive.png',
    'onboarding-rose-peekaboo.png',
    'onboarding-sky-key.png',
    'onboarding-butter-task.png',
    'onboarding-rose-camera.png',
    'onboarding-mint-calendar.png',
    'onboarding-celebrate.png',
  ];

  for (final f in files) {
    final file = File('assets/illustrations/$f');
    assert(file.existsSync(), '$f must exist');
    final image = img.decodeImage(file.readAsBytesSync())!;

    // Check corners for absolute transparency (alpha == 0)
    final cTL = image.getPixel(0, 0);
    final cTR = image.getPixel(image.width - 1, 0);
    final cBL = image.getPixel(0, image.height - 1);
    final cBR = image.getPixel(image.width - 1, image.height - 1);

    int minX = image.width, minY = image.height, maxX = 0, maxY = 0;
    int nonZeroAlpha = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        if (p.a > 5) {
          nonZeroAlpha++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    print('$f: size ${image.width}x${image.height}, corners A=[${cTL.a}, ${cTR.a}, ${cBL.a}, ${cBR.a}], bounds=[$minX, $minY, $maxX, $maxY], w=${maxX-minX}, h=${maxY-minY}, nonZeroAlphaPixels=$nonZeroAlpha');
  }
}
