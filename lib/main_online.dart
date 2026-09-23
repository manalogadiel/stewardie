import 'package:flutter/material.dart';

import 'online/online_app.dart';
import 'online/online_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final backend = await OnlineBackend.start();
    runApp(OnlineApp(backend: backend));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not connect. Check the local service and try again.',
            ),
          ),
        ),
      ),
    );
  }
}
