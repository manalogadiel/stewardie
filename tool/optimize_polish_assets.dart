import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> names) {
  for (final name in names) {
    final file = File('assets/illustrations/$name.png');
    final image = img.decodePng(file.readAsBytesSync())!;
    final edge = name.startsWith('reaction-') ? 192 : 640;
    final resized = image.width > image.height
        ? img.copyResize(
            image,
            width: edge,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            image,
            height: edge,
            interpolation: img.Interpolation.average,
          );
    file.writeAsBytesSync(img.encodePng(resized));
    print(
      '$name: ${resized.width}x${resized.height}, ${file.lengthSync()} bytes',
    );
  }
}
