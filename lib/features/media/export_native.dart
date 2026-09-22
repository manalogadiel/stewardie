import 'dart:typed_data';

import 'package:gal/gal.dart';

Future<String> exportPhoto(Uint8List bytes, String name) async {
  await Gal.putImageBytes(bytes, name: name);
  return 'Saved to your photos.';
}
