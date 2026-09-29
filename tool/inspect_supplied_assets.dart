import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final list = [
    'onboarding-butter-welcome.png',
    'onboarding - attentive.png',
    'onboarding-attentive.png',
    'onboarding sky key.png',
    'onboarding-sky-key.png',
    'onboarding - email verification.png',
    'onboarding-email-verification.png',
    'onboarding - make it yours.png',
    'onboarding-make-it-yours.png',
    'onboarding-butter-task.png',
    'onboarding-rose-camera.png',
    'onboarding-mint-calendar.png',
    'onboarding - done.png',
    'onboarding-done.png',
  ];
  for (final name in list) {
    final file = File('assets/illustrations/$name');
    final im = img.decodeImage(file.readAsBytesSync())!;
    int edgePixels = 0;
    int brightEdgePixels = 0;
    double edgeR = 0, edgeG = 0, edgeB = 0;

    for (int y = 0; y < im.height; y++) {
      for (int x = 0; x < im.width; x++) {
        final p = im.getPixel(x, y);
        if (p.a > 0 && p.a < 255) {
          // Check if it neighbors a transparent pixel (a == 0)
          bool touchesZero = false;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              final nx = x + dx;
              final ny = y + dy;
              if (nx >= 0 && nx < im.width && ny >= 0 && ny < im.height) {
                if (im.getPixel(nx, ny).a == 0) {
                  touchesZero = true;
                  break;
                }
              }
            }
            if (touchesZero) break;
          }

          if (touchesZero) {
            edgePixels++;
            edgeR += p.r;
            edgeG += p.g;
            edgeB += p.b;
            if (p.r > 210 && p.g > 210 && p.b > 210) {
              brightEdgePixels++;
            }
          }
        }
      }
    }
    if (edgePixels > 0) {
      edgeR /= edgePixels;
      edgeG /= edgePixels;
      edgeB /= edgePixels;
    }
    print('$name: ${im.width}x${im.height}, edgePixels=$edgePixels, brightEdges=$brightEdgePixels (${(brightEdgePixels*100/edgePixels).toStringAsFixed(1)}%), avgEdgeRGB=(${edgeR.round()}, ${edgeG.round()}, ${edgeB.round()})');
  }
}
