import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

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
        const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
        const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
        const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
        const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

        if (apiKey.isNotEmpty && appId.isNotEmpty) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: apiKey,
              appId: appId,
              messagingSenderId:
                  messagingSenderId.isNotEmpty ? messagingSenderId : '1234567890',
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
          try {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
          } catch (_) {
            try {
              await Firebase.initializeApp();
            } catch (_) {
              // Fallback for development/offline trial when no config is provided
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
            }
          }
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
    if (useEmulator) {
      final result = await functions
          .httpsCallable(name)
          .call<Map<String, dynamic>>(values);
      return result.data;
    }

    try {
      final result = await functions
          .httpsCallable(name)
          .call<Map<String, dynamic>>(values);
      return result.data;
    } catch (_) {
      // Direct Firestore fallback when Cloud Functions are not deployed (Spark 100% Free Plan)
      return _directFirestoreCall(name, values);
    }
  }

  Future<Map<String, dynamic>> _directFirestoreCall(
    String name,
    Map<String, dynamic> values,
  ) async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('User must be signed in.');
    }
    final uid = user.uid;

    switch (name) {
      case 'createSpace': {
        final spaceRef = firestore.collection('spaces').doc();
        final spaceId = spaceRef.id;
        final spaceName = (values['name'] as String?)?.trim() ?? 'Our Space';
        final kind = (values['kind'] as String?) ?? 'home';
        final timeZone = (values['timeZone'] as String?) ?? 'UTC';

        final spaceData = {
          'name': spaceName,
          'kind': kind,
          'timeZone': timeZone,
          'ownerUid': uid,
          'memberCount': 1,
          'activeTaskCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        };

        final memberData = {
          'uid': uid,
          'role': 'owner',
          'status': 'active',
          'name': user.displayName ?? 'Member',
          'joinedAt': FieldValue.serverTimestamp(),
        };

        final refData = {
          'spaceId': spaceId,
          'name': spaceName,
          'kind': kind,
          'role': 'owner',
          'joinedAt': FieldValue.serverTimestamp(),
        };

        final batch = firestore.batch();
        batch.set(spaceRef, spaceData);
        batch.set(spaceRef.collection('members').doc(uid), memberData);
        batch.set(
          firestore
              .collection('accounts')
              .doc(uid)
              .collection('spaceRefs')
              .doc(spaceId),
          refData,
        );
        batch.set(
          firestore.collection('accounts').doc(uid),
          {'tier': 'basic', 'ownedSpaceCount': 1, 'membershipCount': 1},
          SetOptions(merge: true),
        );
        await batch.commit();

        return {
          'spaceId': spaceId,
          'space': spaceData,
        };
      }

      case 'createTask': {
        final spaceId = values['spaceId'] as String;
        final title = (values['title'] as String).trim();
        final requestedUid = values['requestedUid'] as String?;
        final taskRef = firestore
            .collection('spaces')
            .doc(spaceId)
            .collection('tasks')
            .doc();

        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final data = {
          'id': taskRef.id,
          'title': title,
          'status': requestedUid != null ? 'requested' : 'unclaimed',
          'creatorUid': uid,
          'requestedUid': requestedUid,
          'ownerUid': null,
          'offeredUid': null,
          'scheduledLocalDate': todayStr,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'version': 1,
        };

        await taskRef.set(data);
        return {'task': data};
      }

      case 'actOnTask': {
        final spaceId = values['spaceId'] as String;
        final taskId = values['taskId'] as String;
        final action = values['action'] as String;
        final taskRef = firestore
            .collection('spaces')
            .doc(spaceId)
            .collection('tasks')
            .doc(taskId);

        final snap = await taskRef.get();
        final current = snap.data() ?? {};

        final Map<String, dynamic> update = {
          'updatedAt': FieldValue.serverTimestamp(),
        };

        switch (action) {
          case 'accept':
            update['status'] = 'accepted';
            update['ownerUid'] = uid;
            update['requestedUid'] = null;
            break;
          case 'decline':
            update['status'] = 'unclaimed';
            update['requestedUid'] = null;
            break;
          case 'needHelp':
            update['status'] = 'needsHelp';
            break;
          case 'offerHelp':
            update['offeredUid'] = uid;
            break;
          case 'confirmHandoff':
            update['status'] = 'accepted';
            update['ownerUid'] = current['offeredUid'];
            update['offeredUid'] = null;
            break;
          case 'complete':
            update['status'] = 'completed';
            update['completedAt'] = FieldValue.serverTimestamp();
            update['completedLocalDate'] =
                DateTime.now().toIso8601String().substring(0, 10);
            update['completedBy'] = uid;
            break;
          case 'cancel':
            update['status'] = 'cancelled';
            break;
        }

        await taskRef.update(update);
        return {
          'taskId': taskId,
          'task': {...current, ...update},
        };
      }

      case 'listCompletedTasks': {
        final spaceId = values['spaceId'] as String;
        final query = await firestore
            .collection('spaces')
            .doc(spaceId)
            .collection('tasks')
            .where('status', isEqualTo: 'completed')
            .get();

        final tasks = query.docs.map((d) {
          final data = d.data();
          final rawCompletedAt = data['completedAt'];
          DateTime? completedDate;
          if (rawCompletedAt is Timestamp) {
            completedDate = rawCompletedAt.toDate();
          } else if (rawCompletedAt is String) {
            completedDate = DateTime.tryParse(rawCompletedAt);
          }
          final completedLocal = completedDate ?? DateTime.now();
          final completedDateStr =
              completedLocal.toIso8601String().substring(0, 10);

          return {
            ...data,
            'id': d.id,
            'completedLocalDate':
                data['completedLocalDate'] ?? completedDateStr,
          };
        }).toList();

        return {
          'tasks': tasks,
          'nextCursorId': null,
          'todayLocalDate': DateTime.now().toIso8601String().substring(0, 10),
        };
      }

      case 'setCheckIn': {
        final spaceId = values['spaceId'] as String;
        final checkInRef = firestore
            .collection('spaces')
            .doc(spaceId)
            .collection('checkIns')
            .doc(uid);

        await checkInRef.set({
          'mood': values['mood'],
          'color': values['color'],
          'note': values['note'] ?? '',
          'uid': uid,
          'name': user.displayName ?? 'Member',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return {'ok': true};
      }

      case 'removeCheckIn': {
        final spaceId = values['spaceId'] as String;
        await firestore
            .collection('spaces')
            .doc(spaceId)
            .collection('checkIns')
            .doc(uid)
            .delete();
        return {'ok': true};
      }

      case 'savePlan': {
        final spaceId = values['spaceId'] as String;
        final planId = values['planId'] as String;
        final planRef = firestore
            .collection('spaces')
            .doc(spaceId)
            .collection('plans')
            .doc(planId);

        final planData = {
          'id': planId,
          'spaceId': spaceId,
          'ownerUid': uid,
          'title': values['title'],
          'note': values['note'] ?? '',
          'allDay': values['allDay'] ?? false,
          'startMillis': values['startMillis'],
          'endMillis': values['endMillis'],
          'participants': values['participants'] ?? [],
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await planRef.set(planData);
        return {'planId': planId, 'plan': planData};
      }

      case 'removePlan': {
        final spaceId = values['spaceId'] as String;
        final planId = values['planId'] as String;
        await firestore
            .collection('spaces')
            .doc(spaceId)
            .collection('plans')
            .doc(planId)
            .delete();
        return {'removed': true};
      }

      case 'createInvite': {
        final spaceId = values['spaceId'] as String;
        final spaceSnap =
            await firestore.collection('spaces').doc(spaceId).get();
        final spaceName = spaceSnap.data()?['name'] ?? 'Shared Space';
        final kind = spaceSnap.data()?['kind'] ?? 'home';

        final token = DateTime.now()
            .millisecondsSinceEpoch
            .toRadixString(36)
            .toUpperCase()
            .padLeft(8, '0')
            .substring(0, 8);

        await firestore.collection('invites').doc(token).set({
          'spaceId': spaceId,
          'spaceName': spaceName,
          'kind': kind,
          'creatorUid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return {'token': token};
      }

      case 'previewInvite': {
        final token = values['token'] as String;
        final inviteDoc =
            await firestore.collection('invites').doc(token).get();
        if (!inviteDoc.exists) throw StateError('Invitation code not found.');
        return {
          'spaceId': inviteDoc.data()!['spaceId'] as String,
          'spaceName': inviteDoc.data()?['spaceName'] ?? 'Shared Space',
          'kind': inviteDoc.data()?['kind'] ?? 'home',
        };
      }

      case 'redeemInvite': {
        final token = values['token'] as String;
        final inviteDoc =
            await firestore.collection('invites').doc(token).get();
        if (!inviteDoc.exists) throw StateError('Invitation code not found.');
        final spaceId = inviteDoc.data()!['spaceId'] as String;
        final spaceDoc =
            await firestore.collection('spaces').doc(spaceId).get();
        final spaceName = spaceDoc.data()?['name'] ?? 'Shared Space';
        final kind = spaceDoc.data()?['kind'] ?? 'home';

        final memberData = {
          'uid': uid,
          'role': 'member',
          'status': 'active',
          'name': user.displayName ?? 'Member',
          'joinedAt': FieldValue.serverTimestamp(),
        };

        final refData = {
          'spaceId': spaceId,
          'name': spaceName,
          'kind': kind,
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
        };

        final batch = firestore.batch();
        batch.set(
          firestore
              .collection('spaces')
              .doc(spaceId)
              .collection('members')
              .doc(uid),
          memberData,
        );
        batch.set(
          firestore
              .collection('accounts')
              .doc(uid)
              .collection('spaceRefs')
              .doc(spaceId),
          refData,
        );
        await batch.commit();

        return {'spaceId': spaceId};
      }

      default:
        throw UnimplementedError('Unknown action: $name');
    }
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
