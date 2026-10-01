import 'dart:io';

import 'package:image/image.dart' as image;

void main() {
  final photo = image.Image(width: 32, height: 24);
  image.fill(photo, color: image.ColorRgb8(246, 221, 160));
  File('.local/migration/smoke-photo.jpg')
      .writeAsBytesSync(image.encodeJpg(photo, quality: 80));
}
