import 'dart:math';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/invite_links.dart';
import '../core/space_time.dart';
import '../firebase_options.dart';
part 'spark_backend.dart';

/// Production and local-emulator entry point for Firebase services.
class OnlineBackend {
  OnlineBackend._();

  static const bool useEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  static const String functionsRegion = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );

  static const defaultProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'demo-stewardie',
  );

  static String get host {
    const override = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
    if (override.isNotEmpty) return override;
    // Browser origins treat localhost and 127.0.0.1 separately. Point the
    // emulator SDKs at the same host that served this local preview.
    return kIsWeb ? Uri.base.host : 'localhost';
  }

  static Future<OnlineBackend> start({FirebaseOptions? options}) async {
    if (Firebase.apps.isEmpty) {
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
        const appId = String.fromEnvironment('FIREBASE_APP_ID');
        const messagingSenderId = String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        );
        const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
        const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
        const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

        if (apiKey.isNotEmpty && appId.isNotEmpty) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: apiKey,
              appId: appId,
              messagingSenderId: messagingSenderId.isNotEmpty
                  ? messagingSenderId
                  : '1234567890',
              projectId: projectId.isNotEmpty ? projectId : defaultProjectId,
              authDomain: authDomain.isNotEmpty ? authDomain : null,
              storageBucket: storageBucket.isNotEmpty ? storageBucket : null,
            ),
          );
        } else if (useEmulator) {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: 'local-demo-key',
              appId: '1:1234567890:android:stewardie-local',
              messagingSenderId: '1234567890',
              projectId: defaultProjectId,
              authDomain: '$defaultProjectId.firebaseapp.com',
              storageBucket: '$defaultProjectId.appspot.com',
            ),
          );
        } else {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      }
    }

    if (useEmulator) {
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instanceFor(region: functionsRegion)
          .useFunctionsEmulator(host, 5001);
    }

    return OnlineBackend._();
  }

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseFunctions get functions =>
      FirebaseFunctions.instanceFor(region: functionsRegion);

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> values = const {},
  ]) async {
    // A backend is selected explicitly. A denied/uncertain callable never
    // becomes a less-protected direct write.
    const callable = bool.fromEnvironment('USE_CALLABLE_BACKEND');
    if (callable) {
      final result = await functions
          .httpsCallable(name)
          .call<Map<String, dynamic>>(values);
      return result.data;
    }
    return SparkBackend(this).call(name, values);
  }

  Future<Map<String, dynamic>> callSpaceAction(
    String action,
    String spaceId, {
    String? name,
  }) async {
    const endpoint = String.fromEnvironment(
      'SPACE_ACTIONS_URL',
      defaultValue:
          'https://ulexhxfxatzlobabitpr.supabase.co/functions/v1/space-actions',
    );
    final identityToken = await auth.currentUser?.getIdToken();
    if (identityToken == null) throw StateError('Sign in again.');
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $identityToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'action': action,
        'spaceId': spaceId,
        'name': ?name,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Could not update the space. Please retry.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> register(String name, String email, String password) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(name.trim());
    await credential.user!.sendEmailVerification();
  }

  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Keep account existence out of the recovery response, including when
      // the local emulator uses different enumeration settings from production.
      if (error.code != 'user-not-found') rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> spaces(String uid) => firestore
      .collection('accounts')
      .doc(uid)
      .collection('spaceRefs')
      .snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> account(String uid) =>
      firestore.collection('accounts').doc(uid).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> members(String spaceId) =>
      firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('members')
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> activeTasks(String spaceId) =>
      firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('tasks')
          .where('status', isNotEqualTo: 'completed')
          .snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> checkIn(
    String spaceId,
    String uid,
  ) => firestore
      .collection('spaces')
      .doc(spaceId)
      .collection('checkIns')
      .doc(uid)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> plans(String spaceId) => firestore
      .collection('spaces')
      .doc(spaceId)
      .collection('plans')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> routines(String spaceId) =>
      firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('routines')
          .snapshots();

  /// Fetch individual sessions so Firestore can enforce each recipient and
  /// expiry. A collection listener cannot satisfy those per-document rules.
  Stream<List<Map<String, dynamic>>> locationSessions(String spaceId) async* {
    while (true) {
      try {
        final space = await firestore
            .doc('spaces/$spaceId')
            .get(const GetOptions(source: Source.server));
        final ids = List<String>.from(
          space.data()?['memberUids'] as List? ?? const [],
        );
        final docs = await Future.wait(
          ids.map((uid) async {
            try {
              return await firestore
                  .doc('spaces/$spaceId/locationSessions/$uid')
                  .get(const GetOptions(source: Source.server));
            } catch (_) {
              return null;
            }
          }),
        );
        final now = DateTime.now().toUtc();
        yield [
          for (final doc in docs)
            if (doc?.data() case final data?)
              if (data['expiresAt'] is Timestamp &&
                  (data['expiresAt'] as Timestamp).toDate().isAfter(now))
                data,
        ];
      } catch (_) {
        yield const [];
      }
      await Future<void>.delayed(const Duration(seconds: 15));
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> reactions(
    String spaceId,
    String momentId,
  ) => firestore
      .collection('spaces')
      .doc(spaceId)
      .collection('moments')
      .doc(momentId)
      .collection('reactions')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingJoins(String spaceId) =>
      firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('pendingJoins')
          .snapshots();

  Future<void> setSubtasks(
    String spaceId,
    String taskId,
    List<Map<String, dynamic>> subtasks,
  ) => call('setSubtasks', {
    'spaceId': spaceId,
    'taskId': taskId,
    'subtasks': subtasks,
  });

  Future<void> requestHelp(String spaceId, String taskId) =>
      call('requestHelp', {'spaceId': spaceId, 'taskId': taskId});

  Future<void> takeOverTask(String spaceId, String taskId) =>
      call('takeOverTask', {'spaceId': spaceId, 'taskId': taskId});

  Future<void> createDependentProfile(
    String spaceId, {
    required String name,
    required String familyRole,
    required String color,
  }) => call('createDependentProfile', {
    'spaceId': spaceId,
    'name': name,
    'familyRole': familyRole,
    'color': color,
  });

  Future<void> updateDependentProfile(
    String spaceId,
    String memberId, {
    required String name,
    required String familyRole,
    required String color,
  }) => call('updateDependentProfile', {
    'spaceId': spaceId,
    'memberId': memberId,
    'name': name,
    'familyRole': familyRole,
    'color': color,
  });

  Future<void> deleteDependentProfile(String spaceId, String memberId) => call(
    'deleteDependentProfile',
    {'spaceId': spaceId, 'memberId': memberId},
  );

  Future<void> setJoinApprovalPolicy(String spaceId, bool requireApproval) =>
      call('setJoinApprovalPolicy', {
        'spaceId': spaceId,
        'requireApproval': requireApproval,
      });

  Future<bool> requestJoinSpace(String spaceId, String token) async =>
      (await call('requestJoinSpace', {
        'spaceId': spaceId,
        'token': token,
      }))['approved'] ==
      true;

  Future<void> approveJoinRequest(
    String spaceId,
    String targetUid,
    String targetName,
  ) => call('approveJoinRequest', {
    'spaceId': spaceId,
    'targetUid': targetUid,
    'targetName': targetName,
  });

  Future<void> declineJoinRequest(String spaceId, String targetUid) =>
      call('declineJoinRequest', {'spaceId': spaceId, 'targetUid': targetUid});

  Future<void> updateProfileName(String newName) async {
    final user = auth.currentUser;
    final name = newName.trim();
    if (user == null || name.isEmpty || name.length > 60) return;
    final account = await firestore.doc('accounts/${user.uid}').get();
    final ids = List<String>.from(
      account.data()?['spaceIds'] as List? ?? const [],
    );
    final batch = firestore.batch();
    for (final id in ids) {
      try {
        final member = await firestore
            .doc('spaces/$id/members/${user.uid}')
            .get();
        if (member.exists && member.data()?['status'] == 'active') {
          batch.update(member.reference, {'name': name});
        }
      } catch (_) {
        // A removed space is not a profile-name blocker.
      }
    }
    await batch.commit();
    await user.updateDisplayName(name);
  }

  Future<void> requestAccountDeletion() async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Sign in to request deletion.');
    final request = firestore.collection('deletionRequests').doc(user.uid);
    if ((await request.get()).exists) return;
    await request.set({
      'uid': user.uid,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}
