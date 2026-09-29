import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final pairs = [
    ('Screen 1 (Welcome)', 'onboarding-butter-welcome.png', 'onboarding-butter-welcome.png'),
    ('Screen 2 (Name)', 'onboarding - attentive.png', 'onboarding-attentive.png'),
    ('Screen 3 (Email)', 'onboarding sky key.png', 'onboarding-sky-key.png'),
    ('Screen 4 (Verify)', 'onboarding - email verification.png', 'onboarding-email-verification.png'),
    ('Screen 5 (Yours)', 'onboarding - make it yours.png', 'onboarding-make-it-yours.png'),
    ('Screen 6 (Task)', 'onboarding-butter-task.png', 'onboarding-butter-task.png'),
    ('Screen 6 (Photo)', 'onboarding-rose-camera.png', 'onboarding-rose-camera.png'),
    ('Screen 6 (Cal)', 'onboarding-mint-calendar.png', 'onboarding-mint-calendar.png'),
    ('Screen 7 (Done)', 'onboarding - done.png', 'onboarding-done.png'),
  ];

  print('Screen | Original File -> Fringe% | Clean Derivative -> Fringe%');
  print('---|---|---');

  for (final p in pairs) {
    final origF = p.$2;
    final cleanF = p.$3;

    final origImg = img.decodeImage(File('assets/illustrations/$origF').readAsBytesSync())!;
    final cleanImg = img.decodeImage(File('assets/illustrations/$cleanF').readAsBytesSync())!;

    int origSemi = 0, origFringe = 0;
    for (int y = 0; y < origImg.height; y++) {
      for (int x = 0; x < origImg.width; x++) {
        final pixel = origImg.getPixel(x, y);
        if (pixel.a > 0 && pixel.a < 255) {
          origSemi++;
          if (pixel.r > 200 && pixel.g > 200 && pixel.b > 200) origFringe++;
        }
      }
    }

    int cleanSemi = 0, cleanFringe = 0;
    for (int y = 0; y < cleanImg.height; y++) {
      for (int x = 0; x < cleanImg.width; x++) {
        final pixel = cleanImg.getPixel(x, y);
        if (pixel.a > 0 && pixel.a < 255) {
          cleanSemi++;
          if (pixel.r > 200 && pixel.g > 200 && pixel.b > 200) cleanFringe++;
        }
      }
    }

    final origPct = origSemi > 0 ? (origFringe * 100.0 / origSemi).toStringAsFixed(1) : '0.0';
    final cleanPct = cleanSemi > 0 ? (cleanFringe * 100.0 / cleanSemi).toStringAsFixed(1) : '0.0';

    print('${p.$1} | $origF: ${origImg.width}x${origImg.height} ($origPct%) | $cleanF: ${cleanImg.width}x${cleanImg.height} ($cleanPct%)');
  }
}
