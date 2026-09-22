import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import 'app.dart';
import 'core/demo_state.dart';
import 'features/timeline/data/demo_repository.dart';
import 'features/media/media_library.dart';
import 'features/media/task_storage.dart';
import 'features/media/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = await openLocalDatabase();
    final restored = (await taskRecords.find(db))
        .map((r) => taskFromMap(r.value))
        .toList();
    final timeline = DemoRepository(
      restored: restored,
      persist: (task) async {
        await taskRecords.record(task.id).put(db, taskToMap(task));
      },
    );
    final library = MediaLibrary(
      timeline,
      database: db,
      initial: (await photoRecords.find(db))
          .map((r) => MediaAttachment.fromMap(r.value))
          .toList(),
    );
    runApp(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(timeline),
          mediaLibraryProvider.overrideWithValue(library),
        ],
        child: const StewardieApp(),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your saved space could not be opened. Your data has not been reset.',
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
