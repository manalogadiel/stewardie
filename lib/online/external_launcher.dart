import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
class ExternalLauncher {
  const ExternalLauncher._();

  static Future<void> openMapDirections(
    BuildContext context, {
    required String query,
    double? lat,
    double? lng,
  }) async {
    final destination = lat != null && lng != null
        ? '$lat,$lng'
        : Uri.encodeComponent(query);
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$destination';

    // Copy directions link to clipboard universally
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Map link copied',
            style: TextStyle(fontFamily: 'NunitoSans'),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
