import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// A separate, emulator-only entry point. Production Firebase options are not
/// checked into this repository and no call falls through to a live project.
class OnlineBackend {
  OnlineBackend._();

  static const projectId = 'demo-stewardie';
  static const host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: 'localhost',
  );

  static Future<OnlineBackend> start() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'local-demo-key',
        appId: '1:1234567890:android:stewardie-local',
        messagingSenderId: '1234567890',
        projectId: projectId,
        authDomain: 'demo-stewardie.firebaseapp.com',
        storageBucket: 'demo-stewardie.appspot.com',
      ),
    );
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instanceFor(region: 'us-central1')
        .useFunctionsEmulator(host, 5001);
    return OnlineBackend._();
  }

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseFunctions get functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> values = const {},
  ]) async {
    final result = await functions
        .httpsCallable(name)
        .call<Map<String, dynamic>>(values);
    return result.data;
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
}
