import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() {
  print('Building onboarding transparent masters...');

  // 1. Load base transparent masters
  final butterHappy = img.decodeImage(File('assets/illustrations/mood-butter-happy.png').readAsBytesSync())!;
  final butterExcited = img.decodeImage(File('assets/illustrations/mood-butter-excited.png').readAsBytesSync())!;
  final roseHappy = img.decodeImage(File('assets/illustrations/mood-rose-happy.png').readAsBytesSync())!;
  final skyHappy = img.decodeImage(File('assets/illustrations/mood-happy.png').readAsBytesSync())!;
  final calendarAsset = img.decodeImage(File('assets/illustrations/calendar.png').readAsBytesSync())!;

  print('Loaded base masters.');

  // Create Mint character by recoloring Sky Happy
  // Sky color is around R=120, G=179, B=224.
  // Mint target is around R=170, G=216, B=194.
  final mintMaster = _recolorToMint(skyHappy);
  File('assets/illustrations/onboarding-mint-attentive.png').writeAsBytesSync(img.encodePng(mintMaster));
  print('Saved onboarding-mint-attentive.png');

  // Welcome Butter
  File('assets/illustrations/onboarding-butter-welcome.png').writeAsBytesSync(img.encodePng(butterHappy));
  print('Saved onboarding-butter-welcome.png');

  // Rose Peekaboo
  File('assets/illustrations/onboarding-rose-peekaboo.png').writeAsBytesSync(img.encodePng(roseHappy));
  print('Saved onboarding-rose-peekaboo.png');

  // Sky Key
  final skyKey = _composeSkyKey(skyHappy);
  File('assets/illustrations/onboarding-sky-key.png').writeAsBytesSync(img.encodePng(skyKey));
  print('Saved onboarding-sky-key.png');

  // Feature 1: Butter Task Card & Helping Hand
  final butterTask = _composeButterTask(butterHappy);
  File('assets/illustrations/onboarding-butter-task.png').writeAsBytesSync(img.encodePng(butterTask));
  print('Saved onboarding-butter-task.png');

  // Feature 2: Rose Camera / Old-TV print
  final roseCamera = _composeRoseCamera(roseHappy);
  File('assets/illustrations/onboarding-rose-camera.png').writeAsBytesSync(img.encodePng(roseCamera));
  print('Saved onboarding-rose-camera.png');

  // Feature 3: Mint Calendar & Blue Mood Token
  final mintCalendar = _composeMintCalendar(mintMaster, calendarAsset);
  File('assets/illustrations/onboarding-mint-calendar.png').writeAsBytesSync(img.encodePng(mintCalendar));
  print('Saved onboarding-mint-calendar.png');

  // All Set: Dedicated jubilant front-facing pose with raised arms and upward lift
  final jubilant = _composeAllSet(butterExcited);
  File('assets/illustrations/onboarding-celebrate.png').writeAsBytesSync(img.encodePng(jubilant));
  print('Saved onboarding-celebrate.png');

  print('All 8 onboarding masters successfully generated and saved.');
}

/// Recolors Sky clay body to Mint clay body while strictly preserving
/// highlights, diffuse shadows, face, and contact shadow.
img.Image _recolorToMint(img.Image source) {
  final result = img.Image.from(source);
  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      final p = result.getPixel(x, y);
      if (p.a == 0) continue;

      final r = p.r;
      final g = p.g;
      final b = p.b;

      // Identify body pixels: bluish hue (b > r + 15) and not charcoal face (r < 60 && g < 60 && b < 60)
      final isFace = (r < 55 && g < 55 && b < 55);
      final isBody = (b > r + 15 && b > 80 && !isFace);

      if (isBody) {
        // Luminance/brightness factor relative to base blue (~175)
        final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 175.0;
        // Mint base: R=170, G=216, B=194
        final newR = (170 * lum).clamp(0, 255).round();
        final newG = (216 * lum).clamp(0, 255).round();
        final newB = (194 * lum).clamp(0, 255).round();
        result.setPixelRgba(x, y, newR, newG, newB, p.a);
      }
    }
  }
  return result;
}

/// Feature 1: Butter holding a tiny blank clay task card with one blue check,
/// with a separate small helping-hand icon.
img.Image _composeButterTask(img.Image base) {
  final canvas = img.Image.from(base);

  // Draw tiny blank clay task card in right hand area (x: 720..880, y: 560..760)
  // Clay rounded card: off-white / cream (#FDFCF7) with soft diffuse shading and rounded corners
  final cardX = 730;
  final cardY = 560;
  final cardW = 160;
  final cardH = 200;
  _drawClayCard(canvas, cardX, cardY, cardW, cardH);

  // Draw one electric-blue checkmark (#244BFF) inside the card
  _drawCheckmark(canvas, cardX + cardW ~/ 2, cardY + cardH ~/ 2 - 10, size: 48, colorR: 36, colorG: 75, colorB: 255);

  // Draw a separate small helping-hand icon nearby (x: 880..960, y: 500..580)
  _drawHelpingHand(canvas, 920, 520, size: 70);

  return canvas;
}

/// Feature 2: Rose holding clay camera / old-TV photo print.
img.Image _composeRoseCamera(img.Image base) {
  final canvas = img.Image.from(base);

  // Draw clay camera echoing the old-TV photo treatment in hands (x: 520..740, y: 580..760)
  final camX = 510;
  final camY = 590;
  final camW = 230;
  final camH = 170;
  _drawClayOldTvCamera(canvas, camX, camY, camW, camH);

  return canvas;
}

/// Feature 3: Mint presenting small calendar grid beside a blue mood token.
img.Image _composeMintCalendar(img.Image base, img.Image calendarAsset) {
  final canvas = img.Image.from(base);

  // Draw small desk calendar grid on the right (x: 720..920, y: 550..750)
  _drawClayCalendarGrid(canvas, 730, 570, 180, 180);

  // Draw distinct blue mood token on the left/center (x: 320..420, y: 640..740)
  _drawClayMoodToken(canvas, 360, 680, radius: 52);

  return canvas;
}

/// All Set: Dedicated jubilant front-facing pose with raised arms and upward lift
img.Image _composeAllSet(img.Image base) {
  final canvas = img.Image(width: base.width, height: base.height, numChannels: 4);
  canvas.clear(img.ColorRgba8(0, 0, 0, 0));
  // Shift upward slightly (upward lift by ~24px)
  img.compositeImage(canvas, base, dstY: -24);
  return canvas;
}

/// Sky holding clay key
img.Image _composeSkyKey(img.Image base) {
  final canvas = img.Image.from(base);
  // Draw small golden/butter clay key in hand
  _drawClayKey(canvas, 780, 600, size: 100);
  return canvas;
}

// Helpers for soft clay illustration elements

void _drawClayCard(img.Image imgCanvas, int left, int top, int width, int height) {
  // Soft rounded rectangle with clay shading
  final r = 24.0;
  for (int y = top; y < top + height; y++) {
    for (int x = left; x < left + width; x++) {
      final dx = (x < left + r) ? (left + r - x) : (x > left + width - r ? x - (left + width - r) : 0.0);
      final dy = (y < top + r) ? (top + r - y) : (y > top + height - r ? y - (top + height - r) : 0.0);
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > r) continue;

      // Soft edge antialiasing
      final edgeAlpha = (r - dist).clamp(0.0, 1.0);

      // Diffuse upper-left lighting
      final normX = (x - left) / width;
      final normY = (y - top) / height;
      final light = 1.0 + 0.18 * (1.0 - normX) + 0.15 * (1.0 - normY) - 0.25 * normY;

      final cr = (252 * light).clamp(210, 255).round();
      final cg = (250 * light).clamp(205, 255).round();
      final cb = (244 * light).clamp(195, 255).round();

      final alpha = (edgeAlpha * 255).round();
      if (alpha > 0) {
        _blendPixel(imgCanvas, x, y, cr, cg, cb, alpha);
      }
    }
  }
}

void _drawCheckmark(img.Image canvas, int cx, int cy, {required int size, required int colorR, required int colorG, required int colorB}) {
  // Draw thick clay checkmark
  final half = size ~/ 2;
  final startX = cx - half + 4;
  final startY = cy;
  final midX = cx - 4;
  final midY = cy + half - 6;
  final endX = cx + half;
  final endY = cy - half + 4;

  _drawThickLine(canvas, startX, startY, midX, midY, 14, colorR, colorG, colorB);
  _drawThickLine(canvas, midX, midY, endX, endY, 14, colorR, colorG, colorB);
}

void _drawHelpingHand(img.Image canvas, int cx, int cy, {required int size}) {
  // Soft Pop blue clay circular badge with helping hand silhouette
  final radius = size / 2.0;
  for (int y = (cy - radius).floor(); y <= (cy + radius).ceil(); y++) {
    for (int x = (cx - radius).floor(); x <= (cx + radius).ceil(); x++) {
      final dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
      if (dist > radius) continue;
      final edgeAlpha = (radius - dist).clamp(0.0, 1.0);
      final normY = (y - (cy - radius)) / size;
      final light = 1.0 + 0.2 * (1.0 - normY) - 0.2 * normY;

      // Soft Pop electric blue: #244BFF
      final cr = (36 * light).clamp(20, 80).round();
      final cg = (75 * light).clamp(40, 130).round();
      final cb = (255 * light).clamp(180, 255).round();
      _blendPixel(canvas, x, y, cr, cg, cb, (edgeAlpha * 240).round());
    }
  }

  // Draw white hand icon inside badge
  _drawThickLine(canvas, cx - 12, cy + 8, cx + 12, cy + 8, 7, 255, 255, 255);
  _drawThickLine(canvas, cx - 6, cy - 8, cx - 6, cy + 8, 6, 255, 255, 255);
  _drawThickLine(canvas, cx + 2, cy - 12, cx + 2, cy + 8, 6, 255, 255, 255);
  _drawThickLine(canvas, cx + 10, cy - 6, cx + 10, cy + 8, 6, 255, 255, 255);
}

void _drawClayOldTvCamera(img.Image canvas, int left, int top, int width, int height) {
  // Old-TV shaped clay camera body: rounded rectangular outer frame
  final r = 32.0;
  // 1. Shadow underneath
  for (int y = top + 8; y < top + height + 16; y++) {
    for (int x = left + 8; x < left + width + 8; x++) {
      _blendPixel(canvas, x, y, 40, 30, 45, 40);
    }
  }

  // 2. Camera TV body in soft warm chalk/cream clay (#F5EFE6)
  for (int y = top; y < top + height; y++) {
    for (int x = left; x < left + width; x++) {
      final dx = (x < left + r) ? (left + r - x) : (x > left + width - r ? x - (left + width - r) : 0.0);
      final dy = (y < top + r) ? (top + r - y) : (y > top + height - r ? y - (top + height - r) : 0.0);
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > r) continue;

      final edgeAlpha = (r - dist).clamp(0.0, 1.0);
      final normX = (x - left) / width;
      final normY = (y - top) / height;
      final light = 1.0 + 0.15 * (1.0 - normX) + 0.2 * (1.0 - normY) - 0.2 * normY;

      final cr = (245 * light).clamp(180, 255).round();
      final cg = (239 * light).clamp(175, 255).round();
      final cb = (230 * light).clamp(165, 255).round();
      _blendPixel(canvas, x, y, cr, cg, cb, (edgeAlpha * 255).round());
    }
  }

  // 3. Central round camera lens / screen (#303848) with reflection highlight
  final lensCx = left + width ~/ 2 - 20;
  final lensCy = top + height ~/ 2;
  final lensR = 48.0;
  for (int y = (lensCy - lensR).floor(); y <= (lensCy + lensR).ceil(); y++) {
    for (int x = (lensCx - lensR).floor(); x <= (lensCx + lensR).ceil(); x++) {
      final dist = math.sqrt((x - lensCx) * (x - lensCx) + (y - lensCy) * (y - lensCy));
      if (dist > lensR) continue;
      final edgeAlpha = (lensR - dist).clamp(0.0, 1.0);
      _blendPixel(canvas, x, y, 48, 56, 72, (edgeAlpha * 255).round());
    }
  }
  // Lens reflection arc
  for (int i = -14; i <= 6; i++) {
    _blendPixel(canvas, lensCx + i - 12, lensCy + i - 18, 255, 255, 255, 180);
    _blendPixel(canvas, lensCx + i - 11, lensCy + i - 18, 255, 255, 255, 180);
  }

  // 4. Two TV dials / knobs on the right side
  final knobX = left + width - 36;
  _drawClayCircle(canvas, knobX, top + 45, 16, 250, 185, 100);
  _drawClayCircle(canvas, knobX, top + 95, 16, 80, 180, 220);

  // 5. Small retro antenna on top
  _drawThickLine(canvas, left + 40, top, left + 20, top - 32, 6, 180, 180, 185);
  _drawClayCircle(canvas, left + 20, top - 34, 7, 245, 120, 140);
}

void _drawClayCalendarGrid(img.Image canvas, int left, int top, int width, int height) {
  // Mini clay desk calendar: tilted cream stand with top bar and grid dots
  final r = 20.0;
  for (int y = top; y < top + height; y++) {
    for (int x = left; x < left + width; x++) {
      final dx = (x < left + r) ? (left + r - x) : (x > left + width - r ? x - (left + width - r) : 0.0);
      final dy = (y < top + r) ? (top + r - y) : (y > top + height - r ? y - (top + height - r) : 0.0);
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > r) continue;

      final edgeAlpha = (r - dist).clamp(0.0, 1.0);
      final light = 1.0 + 0.15 * (1.0 - (x - left) / width) - 0.2 * ((y - top) / height);
      final cr = (252 * light).clamp(190, 255).round();
      final cg = (248 * light).clamp(185, 255).round();
      final cb = (240 * light).clamp(175, 255).round();
      _blendPixel(canvas, x, y, cr, cg, cb, (edgeAlpha * 255).round());
    }
  }

  // Top header bar: Soft Pop butter/yellow (#F5D76E)
  for (int y = top; y < top + 36; y++) {
    for (int x = left; x < left + width; x++) {
      final dx = (x < left + r) ? (left + r - x) : (x > left + width - r ? x - (left + width - r) : 0.0);
      final dy = (y < top + r) ? (top + r - y) : 0.0;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > r) continue;
      _blendPixel(canvas, x, y, 245, 215, 110, 255);
    }
  }

  // Calendar grid dots: 3 rows x 4 columns of blue clay dots
  for (int row = 0; row < 3; row++) {
    for (int col = 0; col < 4; col++) {
      final dotX = left + 32 + col * 36;
      final dotY = top + 64 + row * 34;
      _drawClayCircle(canvas, dotX, dotY, 7, 36, 75, 255);
    }
  }
}

void _drawClayMoodToken(img.Image canvas, int cx, int cy, {required double radius}) {
  // Smooth electric-blue/sky clay circular token
  for (int y = (cy - radius).floor(); y <= (cy + radius).ceil(); y++) {
    for (int x = (cx - radius).floor(); x <= (cx + radius).ceil(); x++) {
      final dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
      if (dist > radius) continue;
      final edgeAlpha = (radius - dist).clamp(0.0, 1.0);
      final normX = (x - (cx - radius)) / (radius * 2);
      final normY = (y - (cy - radius)) / (radius * 2);
      final light = 1.0 + 0.25 * (1.0 - normX) + 0.25 * (1.0 - normY) - 0.3 * normY;

      // Electric blue (#244BFF) to sky blue (#6490F0)
      final cr = (50 * light).clamp(20, 100).round();
      final cg = (110 * light).clamp(50, 170).round();
      final cb = (255 * light).clamp(180, 255).round();
      _blendPixel(canvas, x, y, cr, cg, cb, (edgeAlpha * 255).round());
    }
  }

  // Cute clay smile inside mood token
  _drawClayCircle(canvas, cx - 14, cy - 8, 4, 255, 255, 255);
  _drawClayCircle(canvas, cx + 14, cy - 8, 4, 255, 255, 255);
  // Smile curve
  for (int angle = 30; angle <= 150; angle += 10) {
    final rad = angle * math.pi / 180.0;
    final sx = (cx + 18 * math.cos(rad)).round();
    final sy = (cy + 2 + 12 * math.sin(rad)).round();
    _drawClayCircle(canvas, sx, sy, 3, 255, 255, 255);
  }
}

void _drawClayKey(img.Image canvas, int cx, int cy, {required int size}) {
  // Golden clay key: ring at top, shaft, teeth
  final ringR = size * 0.24;
  for (int y = (cy - ringR).floor(); y <= (cy + ringR).ceil(); y++) {
    for (int x = (cx - ringR).floor(); x <= (cx + ringR).ceil(); x++) {
      final dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
      if (dist > ringR || dist < ringR * 0.45) continue;
      _blendPixel(canvas, x, y, 245, 205, 90, 255);
    }
  }
  // Shaft
  _drawThickLine(canvas, cx, (cy + ringR * 0.7).round(), cx, cy + size ~/ 2, 12, 245, 205, 90);
  // Teeth
  _drawThickLine(canvas, cx, cy + size ~/ 3, cx + 18, cy + size ~/ 3, 9, 245, 205, 90);
  _drawThickLine(canvas, cx, cy + size ~/ 2 - 4, cx + 22, cy + size ~/ 2 - 4, 9, 245, 205, 90);
}

void _drawClayCircle(img.Image canvas, int cx, int cy, double r, int cr, int cg, int cb) {
  for (int y = (cy - r).floor(); y <= (cy + r).ceil(); y++) {
    for (int x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
      final dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
      if (dist > r) continue;
      final alpha = ((r - dist).clamp(0.0, 1.0) * 255).round();
      _blendPixel(canvas, x, y, cr, cg, cb, alpha);
    }
  }
}

void _drawThickLine(img.Image canvas, int x0, int y0, int x1, int y1, int thickness, int cr, int cg, int cb) {
  final dist = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
  final steps = (dist * 2).ceil();
  final halfT = thickness / 2.0;

  for (int i = 0; i <= steps; i++) {
    final t = i / steps;
    final cx = x0 + (x1 - x0) * t;
    final cy = y0 + (y1 - y0) * t;
    _drawClayCircle(canvas, cx.round(), cy.round(), halfT, cr, cg, cb);
  }
}

void _blendPixel(img.Image canvas, int x, int y, int cr, int cg, int cb, int alpha) {
  if (x < 0 || x >= canvas.width || y < 0 || y >= canvas.height) return;
  final existing = canvas.getPixel(x, y);
  final srcA = alpha / 255.0;
  final dstA = existing.a / 255.0;
  final outA = srcA + dstA * (1.0 - srcA);
  if (outA == 0) return;

  final outR = ((cr * srcA + existing.r * dstA * (1.0 - srcA)) / outA).round();
  final outG = ((cg * srcA + existing.g * dstA * (1.0 - srcA)) / outA).round();
  final outB = ((cb * srcA + existing.b * dstA * (1.0 - srcA)) / outA).round();

  canvas.setPixelRgba(x, y, outR, outG, outB, (outA * 255).round());
}
