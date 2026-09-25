import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/invite_links.dart';
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
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
}
