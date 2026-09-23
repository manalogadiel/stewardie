import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../online/online_backend.dart';

// Null only in the explicitly selected fixture entry point and widget tests.
final sharedBackendProvider = Provider<OnlineBackend?>((ref) => null);
