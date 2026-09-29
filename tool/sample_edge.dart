import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final im = img.decodeImage(File('assets/illustrations/onboarding - email verification.png').readAsBytesSync())!;
  for (int y = 170; y < 178; y++) {
    for (int x = 735; x < 745; x++) {
      final p = im.getPixel(x, y);
      if (p.a > 0 && p.a < 255) {
        print('($x,$y): R=${p.r}, G=${p.g}, B=${p.b}, A=${p.a}');
      }
    }
  }
}
