import 'dart:io';
import 'package:image/image.dart' as img;

img.Image processDerivative(img.Image src, {int targetWidth = 1254, int targetHeight = 1254}) {
  // 1. If not target size, center on target canvas
  img.Image canvas;
  if (src.width != targetWidth || src.height != targetHeight) {
    canvas = img.Image(width: targetWidth, height: targetHeight, numChannels: 4);
    final ox = (targetWidth - src.width) ~/ 2;
    final oy = (targetHeight - src.height) ~/ 2;
    img.compositeImage(canvas, src, dstX: ox, dstY: oy);
  } else {
    canvas = src.clone();
  }

  // 2. Identify opaque core (a > 220) and find character colors
  // For each semi-transparent pixel, find the closest opaque interior pixel (within radius 4)
  // to remove white background contamination while keeping the soft anti-aliased edge.
  final result = canvas.clone();

  for (int y = 0; y < canvas.height; y++) {
    for (int x = 0; x < canvas.width; x++) {
      final p = canvas.getPixel(x, y);
      if (p.a == 0) continue;

      // Filter out stray dust where alpha is extremely low
      if (p.a < 12) {
        result.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }

      // If semi-transparent boundary pixel
      if (p.a < 235) {
        // Search nearest solid pixel (a >= 235) in neighborhood
        int bestDistSq = 999;
        int nearR = p.r.toInt(), nearG = p.g.toInt(), nearB = p.b.toInt();
        bool found = false;

        for (int dy = -4; dy <= 4; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= canvas.height) continue;
          for (int dx = -4; dx <= 4; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= canvas.width) continue;
            final np = canvas.getPixel(nx, ny);
            if (np.a >= 235) {
              final dsq = dx * dx + dy * dy;
              if (dsq < bestDistSq) {
                bestDistSq = dsq;
                nearR = np.r.toInt();
                nearG = np.g.toInt();
                nearB = np.b.toInt();
                found = true;
              }
            }
          }
        }

        if (found) {
          // The observed color may be contaminated by white background (255,255,255).
          // We blend the RGB toward the true interior color based on alpha.
          // Lower alpha means more background contamination had occurred.
          final alphaNorm = p.a / 255.0;
          // Un-premultiply assuming white contamination if observed is brighter than near color:
          int cr = p.r.toInt();
          int cg = p.g.toInt();
          int cb = p.b.toInt();

          // Defringe: if pixel is brighter than interior color, pull it down to near color
          if (cr > nearR) cr = (nearR * (1 - alphaNorm) + cr * alphaNorm).round().clamp(0, 255);
          if (cg > nearG) cg = (nearG * (1 - alphaNorm) + cg * alphaNorm).round().clamp(0, 255);
          if (cb > nearB) cb = (nearB * (1 - alphaNorm) + cb * alphaNorm).round().clamp(0, 255);

          // For very edge pixels (a < 120), adopt the true character color so anti-aliasing against
          // ANY canvas background (cream, sky, dark) is completely halo-free!
          if (p.a < 120) {
            cr = nearR;
            cg = nearG;
            cb = nearB;
          }

          result.setPixelRgba(x, y, cr, cg, cb, p.a);
        }
      }
    }
  }

  return result;
}

void main() {
  print('Creating clean derivatives of user-supplied assets...');

  final mappings = [
    // Source -> Derivative
    ('onboarding - attentive.png', 'onboarding-attentive.png'),
    ('onboarding sky key.png', 'onboarding-sky-key.png'),
    ('onboarding - email verification.png', 'onboarding-email-verification.png'),
    ('onboarding - make it yours.png', 'onboarding-make-it-yours.png'),
    ('onboarding - done.png', 'onboarding-done.png'),
  ];

  for (final m in mappings) {
    final srcFile = File('assets/illustrations/${m.$1}');
    if (!srcFile.existsSync()) {
      print('ERROR: Missing source ${m.$1}');
      continue;
    }
    final src = img.decodeImage(srcFile.readAsBytesSync())!;
    final cleaned = processDerivative(src);
    final outFile = File('assets/illustrations/${m.$2}');
    outFile.writeAsBytesSync(img.encodePng(cleaned));
    print('Generated ${m.$2} from ${m.$1} (${cleaned.width}x${cleaned.height})');
  }

  print('Done.');
}
