part of 'online_backend.dart';

/// Explicit Spark transport. All permissions and transitions are also enforced
/// by firestore.rules; client checks only improve error messages.
class SparkBackend {
  SparkBackend(this.backend);
  final OnlineBackend backend;
  FirebaseFirestore get db => backend.firestore;
  User get user => backend.auth.currentUser!;
  String get uid => user.uid;
  DocumentReference<Map<String, dynamic>> space(String id) =>
      db.doc('spaces/$id');
  String day(DateTime time) => time.toUtc().toIso8601String().substring(0, 10);
  Map<String, dynamic> member(String role) => {
    'uid': uid,
    'name': user.displayName?.trim().isNotEmpty == true
        ? user.displayName
        : 'Member',
    'role': role,
    'status': 'active',
    'joinedAt': FieldValue.serverTimestamp(),
  };
  Map<String, dynamic> reference(String id, Map<String, dynamic> data) => {
    'spaceId': id,
    'name': data['name'],
    'kind': data['kind'],
    'joinedAt': FieldValue.serverTimestamp(),
  };
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> v,
  ) async {
    if (backend.auth.currentUser?.emailVerified != true) {
      throw StateError('Sign in with a verified email first.');
    }
    final id = v['spaceId'] as String?;
    switch (action) {
      case 'createSpace':
        final ref = space(db.collection('spaces').doc().id);
        final data = <String, dynamic>{
          'name': (v['name'] as String).trim(),
          'kind': v['kind'],
          'timeZone': v['timeZone'],
          'ownerUid': uid,
          'memberUids': [uid],
          'memberCount': 1,
          'activeTaskCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await db.runTransaction((tx) async {
          final account = db.doc('accounts/$uid');
          final old = (await tx.get(account)).data() ?? {};
          tx.set(ref, data);
          tx.set(ref.collection('members').doc(uid), member('owner'));
          tx.set(
            account.collection('spaceRefs').doc(ref.id),
            reference(ref.id, data),
          );
          tx.set(account, {
            ...old,
            'tier': old['tier'] ?? 'basic',
            'spaceIds': [...List<String>.from(old['spaceIds'] ?? []), ref.id],
            'ownedSpaceIds': [
              ...List<String>.from(old['ownedSpaceIds'] ?? []),
              ref.id,
            ],
            'changedSpaceId': ref.id,
          });
        });
        return {'spaceId': ref.id};
      case 'createTask':
        final ref = space(id!)
            .collection('tasks')
            .doc(v['operationId'] as String?);
        await db.runTransaction((tx) async {
          final existing = await tx.get(ref);
          final parent = await tx.get(space(id));
          if (existing.exists) {
            if (existing.data()?['creatorUid'] != uid ||
                existing.data()?['title'] != (v['title'] as String).trim()) {
              throw StateError('This task request has already been used.');
            }
            return;
          }
          tx.set(ref, {
            'title': (v['title'] as String).trim(),
            'creatorUid': uid,
            'requestedUid': v['requestedUid'],
            'ownerUid': null,
            'offeredUid': null,
            'status': v['requestedUid'] == null ? 'unclaimed' : 'requested',
            'scheduledLocalDate': day(DateTime.now()),
            'version': 1,
            'completedAt': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.update(space(id), {
            'activeTaskCount':
                (parent.data()?['activeTaskCount'] as int? ?? 0) + 1,
            'changedTaskId': ref.id,
          });
        });
        return {'taskId': ref.id};
      case 'actOnTask':
        final ref = space(id!).collection('tasks').doc(v['taskId'] as String);
        final operation = v['operationId'] as String;
        await db.runTransaction((tx) async {
          final current = (await tx.get(ref)).data();
          final parent = (await tx.get(space(id))).data()!;
          final receipt = ref.collection('operations').doc('${uid}_$operation');
          final previous = await tx.get(receipt);
          if (previous.exists) {
            if (previous.data()?['action'] != v['action'])
              throw StateError('This operation was already used.');
            return;
          }
          if (current == null)
            throw StateError('This task is no longer available.');
          final changes = <String, dynamic>{
            'updatedAt': FieldValue.serverTimestamp(),
            'version': (current['version'] as int? ?? 0) + 1,
          };
          switch (v['action']) {
            case 'accept':
              changes.addAll({
                'status': 'accepted',
                'ownerUid': uid,
                'requestedUid': null,
                'offeredUid': null,
              });
            case 'decline':
              changes.addAll({'status': 'unclaimed', 'requestedUid': null});
            case 'needHelp':
              changes['status'] = 'needsHelp';
            case 'offerHelp':
              changes['offeredUid'] = uid;
            case 'confirmHandoff':
              changes.addAll({
                'status': 'accepted',
                'ownerUid': current['offeredUid'],
                'offeredUid': null,
              });
            case 'complete':
              tx.set(space(id).collection('taskCompletions').doc(ref.id), {
                'title': current['title'],
                'ownerUid': current['ownerUid'],
                'completedAt': FieldValue.serverTimestamp(),
              });
              changes.addAll({
                'status': 'completed',
                'offeredUid': null,
                'completedAt': FieldValue.serverTimestamp(),
                'completedLocalDate': day(DateTime.now()),
              });
              tx.update(space(id), {
                'activeTaskCount': (parent['activeTaskCount'] as int) - 1,
                'changedTaskId': ref.id,
              });
            default:
              throw StateError('This action is unavailable.');
          }
          tx.update(ref, changes);
          tx.set(receipt, {
            'actorUid': uid,
            'version': changes['version'],
            'action': v['action'],
            'appliedAt': FieldValue.serverTimestamp(),
          });
        });
        return {
          'taskId': ref.id,
          'task': (await ref.get(const GetOptions(source: Source.server)))
              .data(),
        };
      case 'listCompletedTasks':
        final plus =
            (await db.doc('accounts/$uid').get()).data()?['tier'] == 'plus';
        Query<Map<String, dynamic>> query = space(id!)
            .collection('tasks')
            .where('status', isEqualTo: 'completed');
        final now = DateTime.now().toUtc();
        if (!plus)
          query = query.where(
            'completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime.utc(
                now.year,
                now.month,
                now.day,
              ).subtract(const Duration(days: 3)),
            ),
          );
        query = query.orderBy('completedAt', descending: true).limit(50);
        if (v['cursorId'] != null) {
          final cursor = await space(id)
              .collection('tasks')
              .doc(v['cursorId'] as String)
              .get();
          if (cursor.exists) query = query.startAfterDocument(cursor);
        }
        final docs = (await query.get()).docs;
        return {
          'tasks': docs.map((d) => {...d.data(), 'id': d.id}).toList(),
          'todayLocalDate': day(now),
          'nextCursorId': docs.length == 50 ? docs.last.id : null,
        };
      case 'setCheckIn':
        final now = DateTime.now().toUtc();
        await space(id!).collection('checkIns').doc(uid).set({
          'uid': uid,
          'mood': v['mood'],
          'color': v['color'],
          'note': v['note'] ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.utc(now.year, now.month, now.day + 1),
          ),
        });
        return {'ok': true};
      case 'removeCheckIn':
        await space(id!).collection('checkIns').doc(uid).delete();
        return {'ok': true};
      case 'savePlan':
        await space(id!).collection('plans').doc(v['planId'] as String).set({
          'ownerUid': uid,
          'title': v['title'],
          'note': v['note'] ?? '',
          'allDay': v['allDay'],
          'startMillis': v['startMillis'],
          'endMillis': v['endMillis'],
          'participants': v['participants'] ?? [],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return {'planId': v['planId']};
      case 'removePlan':
        await space(id!)
            .collection('plans')
            .doc(v['planId'] as String)
            .delete();
        return {'removed': true};
      case 'createInvite':
        final data = (await space(id!).get()).data()!;
        final random = Random.secure();
        final token = base64UrlEncode(
          List.generate(24, (_) => random.nextInt(256)),
        );
        await db.doc('invites/$token').set({
          'spaceId': id,
          'spaceName': data['name'],
          'kind': data['kind'],
          'creatorUid': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
          'redeemedUid': null,
          'revoked': false,
        });
        return {'token': token};
      case 'previewInvite':
        final data = (await db.doc('invites/${v['token']}').get()).data();
        if (data == null ||
            data['revoked'] == true ||
            data['redeemedUid'] != null ||
            (data['expiresAt'] as Timestamp).toDate().isBefore(
              DateTime.now(),
            )) {
          throw StateError(
            'This invitation has expired or was already used. Ask for a new code.',
          );
        }
        return data;
      case 'redeemInvite':
        String? joined;
        await db.runTransaction((tx) async {
          final invite = db.doc('invites/${v['token']}');
          final data = (await tx.get(invite)).data()!;
          joined = data['spaceId'] as String;
          final account = db.doc('accounts/$uid');
          final old = (await tx.get(account)).data() ?? {};
          if (List.from(old['spaceIds'] ?? []).contains(joined)) return;
          tx.update(invite, {'redeemedUid': uid});
          tx.update(space(joined!), {
            'memberUids': FieldValue.arrayUnion([uid]),
            'memberCount': FieldValue.increment(1),
            'joinToken': v['token'],
          });
          tx.set(space(joined!).collection('members').doc(uid), {
            ...member('member'),
            'joinToken': v['token'],
          });
          tx.set(
            account.collection('spaceRefs').doc(joined),
            reference(joined!, {
              'name': data['spaceName'],
              'kind': data['kind'],
            }),
          );
          tx.set(account, {
            ...old,
            'tier': old['tier'] ?? 'basic',
            'spaceIds': [...List.from(old['spaceIds'] ?? []), joined],
            'ownedSpaceIds': old['ownedSpaceIds'] ?? [],
            'changedSpaceId': joined,
          });
        });
        return {'spaceId': joined};
      case 'revokeInvite':
        await db.doc('invites/${v['token']}').update({'revoked': true});
        return {'ok': true};
      case 'removeMember':
      case 'leaveSpace':
        final target = action == 'leaveSpace' ? uid : v['memberUid'] as String;
        final tasks = await space(id!)
            .collection('tasks')
            .where('status', isNotEqualTo: 'completed')
            .get();
        await db.runTransaction((tx) async {
          final parent = (await tx.get(space(id))).data()!;
          final account = db.doc('accounts/$target');
          final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
          for (final task in tasks.docs) {
            snapshots.add(await tx.get(task.reference));
          }
          if (parent['ownerUid'] == target)
            throw StateError('Transfer ownership before leaving this space.');
          tx.update(space(id), {
            'memberUids': FieldValue.arrayRemove([target]),
            'memberCount': FieldValue.increment(-1),
            'removedUid': target,
          });
          tx.update(space(id).collection('members').doc(target), {
            'status': 'removed',
          });
          tx.delete(account.collection('spaceRefs').doc(id));
          tx.update(account, {
            'spaceIds': FieldValue.arrayRemove([id]),
            'ownedSpaceIds': FieldValue.arrayRemove([id]),
            'changedSpaceId': id,
          });
          for (final task in snapshots) {
            final data = task.data()!;
            if (data['status'] == 'completed') continue;
            if (data['ownerUid'] == target || data['requestedUid'] == target) {
              tx.update(task.reference, {
                'status': 'unclaimed',
                'ownerUid': null,
                'requestedUid': null,
                'offeredUid': null,
                'version': (data['version'] as int) + 1,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } else if (data['offeredUid'] == target) {
              tx.update(task.reference, {
                'offeredUid': null,
                'version': (data['version'] as int) + 1,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        });
        return {'ok': true};
      case 'offerOwnership':
        await space(id!).update({'pendingOwnerUid': v['memberUid']});
        return {'ok': true};
      case 'acceptOwnership':
        await db.runTransaction((tx) async {
          final parent = (await tx.get(space(id!))).data()!;
          tx.update(space(id), {'ownerUid': uid, 'pendingOwnerUid': null});
          tx.update(db.doc('accounts/$uid'), {
            'ownedSpaceIds': FieldValue.arrayUnion([id]),
            'changedSpaceId': id,
          });
          tx.update(db.doc('accounts/${parent['ownerUid']}'), {
            'ownedSpaceIds': FieldValue.arrayRemove([id]),
            'changedSpaceId': id,
          });
          tx.update(
            space(id).collection('members').doc(parent['ownerUid'] as String),
            {'role': 'member'},
          );
          tx.update(space(id).collection('members').doc(uid), {
            'role': 'owner',
          });
        });
        return {'ok': true};
      default:
        throw StateError('This action is not available.');
    }
  }
}
