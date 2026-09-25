import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stewardie/online/login_scene.dart';

// Asset authoring command: flutter test tool/render_welcome_asset.dart
void main() {
  test(
    'render original clay wave into a looping GIF and static fallback',
    () async {
      final encoder = img.GifEncoder(repeat: 0);
      for (var frame = 0; frame < 32; frame++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xFFFAF9F6), BlendMode.src);
        WelcomeWavePainter(frame / 32).paint(canvas, const Size(240, 240));
        final picture = recorder.endRecording();
        final image = await picture.toImage(240, 240);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        if (frame == 0) {
          await File('assets/illustrations/welcome-wave.png')
              .writeAsBytes(bytes);
        }
        encoder.addFrame(img.decodePng(bytes)!, duration: 7);
        image.dispose();
        picture.dispose();
      }
      await File('assets/illustrations/welcome-wave.gif')
          .writeAsBytes(encoder.finish()!);
    },
  );
}
