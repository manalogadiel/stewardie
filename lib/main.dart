import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'core/place_search.dart';
import 'features/media/store.dart';
import 'online/firebase_session.dart';
import 'online/online_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configurePlaceSearch();
  // Paint edge to edge; each shell keeps interactive controls in safe areas.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    final database = await openLocalDatabase();
    final backend = await OnlineBackend.start();
    runApp(FirebaseSessionApp(backend: backend, database: database));
  } catch (_) {
    runApp(
      MaterialApp(
        theme: SoftPop.theme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Could not open Stewardie. Your saved photos have not been reset.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: main, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
