import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sembast/sembast.dart' hide FieldValue;

import '../../online/online_backend.dart';

/// The 8 distinct steps in the welcome and account onboarding flow.
enum OnboardingStep {
  welcome(0.0),
  name(1 / 7),
  account(2 / 7),
  verifyEmail(3 / 7),
  permissions(4 / 7),
  profile(5 / 7),
  features(6 / 7),
  allSet(1.0);

  const OnboardingStep(this.progress);
  final double progress;

  static OnboardingStep fromIndex(int index) {
    if (index < 0) return OnboardingStep.welcome;
    if (index >= OnboardingStep.values.length) return OnboardingStep.allSet;
    return OnboardingStep.values[index];
  }
}

/// Manages draft persistence, cooldown timers, and completion records for Onboarding.
///
/// Security & Privacy:
/// - Passwords and Firebase action tokens are NEVER persisted.
/// - Pre-auth drafts are local to this device installation.
/// - Post-auth drafts are bound strictly to the authenticated Firebase UID.
/// - Completion records are versioned and UID-scoped.
class OnboardingStore {
  OnboardingStore(this.database);

  final Database? database;

  static const int currentSchemaVersion = 2;

  static final _store = stringMapStoreFactory.store('onboarding_v1');

  static String _draftKey(String? uid) =>
      uid != null && uid.isNotEmpty ? 'draft_$uid' : 'draft_pre_auth';

  static String _completionKey(String uid) => 'completed_$uid';

  /// Saves the current progress and field drafts. Never stores passwords.
  Future<void> saveDraft({
    String? uid,
    required OnboardingStep step,
    String? name,
    String? email,
    String? avatarBase64,
    bool clearAvatar = false,
    int? featurePageIndex,
    Map<String, dynamic>? permissions,
  }) async {
    final db = database;
    if (db == null) return;

    final key = _draftKey(uid);
    final existing = await _store.record(key).get(db) ?? <String, dynamic>{};

    final updated = Map<String, dynamic>.from(existing);
    updated['schemaVersion'] = currentSchemaVersion;
    updated['stepIndex'] = step.index;
    updated['stepId'] = step.name;
    if (name != null) updated['name'] = name.trim();
    if (email != null) updated['email'] = email.trim();
    if (clearAvatar) updated.remove('avatarBase64');
    if (avatarBase64 != null) updated['avatarBase64'] = avatarBase64;
    updated.remove('adultConfirmed'); // Migrate legacy draft
    if (featurePageIndex != null)
      updated['featurePageIndex'] = featurePageIndex;
    if (permissions != null) updated['permissions'] = permissions;
    updated['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    await _store.record(key).put(db, updated);
  }

  /// Loads saved draft for the given user (or pre-auth device draft).
  Future<Map<String, dynamic>?> loadDraft(String? uid) async {
    final db = database;
    if (db == null) return null;
    final key = _draftKey(uid);
    final record = await _store.record(key).get(db);
    if (record == null) return null;
    final result = Map<String, dynamic>.from(record);
    final savedId = result['stepId'];
    if (savedId is String) {
      result['stepIndex'] = OnboardingStep.values.firstWhere(
        (step) => step.name == savedId, orElse: () => OnboardingStep.welcome).index;
    } else if ((result['schemaVersion'] as int? ?? 1) < 2) {
      const legacy = ['welcome', 'name', 'account', 'verifyEmail', 'permissions', 'features', 'allSet'];
      final index = (result['stepIndex'] as int? ?? 0).clamp(0, legacy.length - 1);
      result['stepId'] = legacy[index];
      result['stepIndex'] = OnboardingStep.values.firstWhere((step) => step.name == legacy[index]).index;
    }
    return result;
  }

  /// Clears the draft (e.g. upon completion or sign-out).
  Future<void> clearDraft(String? uid) async {
    final db = database;
    if (db == null) return;
    await _store.record(_draftKey(uid)).delete(db);
    if (uid != null) {
      await _store.record(_draftKey(null)).delete(db);
    }
  }

  Future<void> savePendingAvatar(String uid, String avatarBase64) async {
    if (database == null) return;
    await _store.record('pending_avatar_$uid').put(database!, {
      'image': avatarBase64,
    });
  }

  Future<String?> pendingAvatar(String uid) async {
    if (database == null) return null;
    return (await _store.record('pending_avatar_$uid').get(database!))?['image']
        as String?;
  }

  Future<void> clearPendingAvatar(String uid) async {
    if (database != null)
      await _store.record('pending_avatar_$uid').delete(database!);
  }

  /// Records email verification resend timestamp to enforce at least 30s cooldown.
  Future<void> recordResendTimestamp(String? uid) async {
    final db = database;
    if (db == null) return;
    final key = _draftKey(uid);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _store.record(key).get(db) ?? <String, dynamic>{};
    final updated = Map<String, dynamic>.from(existing);
    updated['lastResendEpochMs'] = now;
    await _store.record(key).put(db, updated);
  }

  /// Returns remaining cooldown seconds (0 if allowed to resend now).
  Future<int> getRemainingCooldownSeconds(String? uid) async {
    final db = database;
    if (db == null) return 0;
    final draft = await loadDraft(uid);
    final lastEpoch = draft?['lastResendEpochMs'] as int?;
    if (lastEpoch == null) return 0;

    final elapsedSeconds =
        (DateTime.now().millisecondsSinceEpoch - lastEpoch) ~/ 1000;
    const minCooldown = 30;
    if (elapsedSeconds < minCooldown) {
      return minCooldown - elapsedSeconds;
    }
    return 0;
  }

  /// Checks if this user has already completed onboarding locally or on Firestore.
  /// Includes legacy user verification to avoid trapping users with existing spaces.
  Future<bool> isCompleted(String uid, {OnlineBackend? backend}) async {
    if (uid.isEmpty) return false;
    final db = database;
    if (db != null) {
      final record = await _store.record(_completionKey(uid)).get(db);
      if (record?['completed'] == true) return true;
    }

    if (backend != null) {
      try {
        final doc = await backend.firestore
            .collection('accounts')
            .doc(uid)
            .get();
        if (doc.exists && doc.data()?['onboardingCompleted'] == true) {
          if (db != null) {
            await markCompleted(uid);
          }
          return true;
        }

        // Legacy safety: check if user already belongs to any spaces
        final spacesSnap = await backend.firestore
            .collection('spaces')
            .where('members.$uid.role', isNull: false)
            .limit(1)
            .get();
        if (spacesSnap.docs.isNotEmpty) {
          if (db != null) {
            await markCompleted(uid);
          }
          return true;
        }
      } catch (_) {
        // Network/permission issues should not crash check
      }
    }

    return false;
  }

  /// Marks onboarding completed locally and attempts non-blocking Firestore sync.
  Future<void> markCompleted(String uid, {OnlineBackend? backend}) async {
    if (uid.isEmpty) return;
    final db = database;
    if (db != null) {
      await _store.record(_completionKey(uid)).put(db, {
        'completed': true,
        'version': currentSchemaVersion,
        'completedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await clearDraft(uid);
    }

    // Sync to Firestore accounts/{uid} if backend is provided (non-blocking)
    if (backend != null) {
      try {
        await backend.firestore.collection('accounts').doc(uid).set({
          'onboardingCompleted': true,
          'onboardingVersion': currentSchemaVersion,
          'onboardingCompletedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // Offline or permissions glitch must never block verified app access
      }
    }
  }
}
