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
  void addSpaceEvent(
    Transaction tx,
    String spaceId,
    String eventId, {
    required String type,
    required String entityId,
    required List<String> recipients,
    String? targetUid,
    List<String>? affectedUids,
    int? taskVersion,
    int? planRevision,
  }) {
    tx.set(space(spaceId).collection('events').doc(eventId), {
      'type': type,
      'actorUid': uid,
      'entityId': entityId,
      'targetUid': targetUid,
      'recipientUids': recipients,
      if (affectedUids != null) 'affectedUids': affectedUids,
      if (taskVersion != null) 'taskVersion': taskVersion,
      if (planRevision != null) 'planRevision': planRevision,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

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
          final accountSnap = await tx.get(account);
          final old = accountSnap.data() ?? {};
          tx.set(ref, data);
          tx.set(ref.collection('members').doc(uid), member('owner'));
          tx.set(
            account.collection('spaceRefs').doc(ref.id),
            reference(ref.id, data),
          );
          final newSpaceIds = [
            ...List<String>.from((old['spaceIds'] as Iterable?) ?? const []),
            ref.id,
          ];
          final newOwnedSpaceIds = [
            ...List<String>.from(
              (old['ownedSpaceIds'] as Iterable?) ?? const [],
            ),
            ref.id,
          ];
          if (accountSnap.exists) {
            tx.update(account, {
              'spaceIds': newSpaceIds,
              'ownedSpaceIds': newOwnedSpaceIds,
              'changedSpaceId': ref.id,
            });
          } else {
            tx.set(account, {
              'tier': old['tier'] ?? 'basic',
              'spaceIds': newSpaceIds,
              'ownedSpaceIds': newOwnedSpaceIds,
              'changedSpaceId': ref.id,
            });
          }
        });
        return {'spaceId': ref.id};
      case 'createTask':
        checkedTaskName(v['title'] as String);
        final requestedDay = v['scheduledLocalDate'] as String?;
        if (requestedDay != null &&
            !RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(requestedDay)) {
          throw ArgumentError('Check the task date.');
        }
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
            if (v['pin'] != null) 'pin': v['pin'],
            'creatorUid': uid,
            'requestedUid': v['requestedUid'],
            'ownerUid': null,
            'offeredUid': null,
            'status': v['requestedUid'] == null ? 'unclaimed' : 'requested',
            'scheduledLocalDate': requestedDay ?? day(DateTime.now()),
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
          if (v['requestedUid'] != null) {
            addSpaceEvent(
              tx,
              id,
              'task_${ref.id}_1',
              type: 'taskAssigned',
              entityId: ref.id,
              taskVersion: 1,
              targetUid: v['requestedUid'] as String,
              recipients: List<String>.from(
                parent.data()?['memberUids'] as List? ?? [],
              ),
            );
          }
        });
        return {'taskId': ref.id};
      case 'actOnTask':
        final ref = space(id!).collection('tasks').doc(v['taskId'] as String);
        final operation = v['operationId'] as String;
        await db.runTransaction((tx) async {
          final receipt = ref.collection('operations').doc('${uid}_$operation');
          final previous = await tx.get(receipt);
          if (previous.exists) {
            if (previous.data()?['action'] != v['action']) {
              throw StateError('This operation was already used.');
            }
            return;
          }
          final current = (await tx.get(ref)).data();
          final parent = (await tx.get(space(id))).data()!;
          if (current == null) {
            throw StateError('This task is no longer available.');
          }
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
          final eventType = switch (v['action']) {
            'needHelp' => 'helpRequested',
            'accept' || 'confirmHandoff' => 'covered',
            'complete' => 'completed',
            'offerHelp' => 'helpOffered',
            'decline' => 'taskDeclined',
            _ => null,
          };
          if (eventType != null) {
            addSpaceEvent(
              tx,
              id,
              'task_${ref.id}_${changes['version']}',
              type: eventType,
              entityId: ref.id,
              taskVersion: eventType == 'helpOffered'
                  ? changes['version'] as int
                  : null,
              targetUid: eventType == 'helpOffered'
                  ? current['ownerUid'] as String?
                  : eventType == 'covered' || eventType == 'taskDeclined'
                  ? current['creatorUid'] as String?
                  : null,
              recipients: List<String>.from(
                parent['memberUids'] as List? ?? [],
              ),
              affectedUids: eventType != 'helpRequested'
                  ? {
                      for (final value in [
                        current['creatorUid'],
                        current['ownerUid'],
                        current['requestedUid'],
                        current['offeredUid'],
                      ])
                        if (value is String) value,
                    }.toList()
                  : null,
            );
          }
          tx.set(receipt, {
            'actorUid': uid,
            'version': changes['version'],
            'action': v['action'],
            'appliedAt': FieldValue.serverTimestamp(),
          });
        });
        return {'taskId': ref.id, 'ok': true};
      case 'markTaskDone':
        final opId =
            v['operationId'] as String? ??
            db.collection('operationIds').doc().id;
        return call('actOnTask', {
          'spaceId': v['spaceId'] ?? id,
          'taskId': v['taskId'],
          'operationId': opId,
          'action': 'complete',
        });
      case 'listCompletedTasks':
        return backend.taskAccess('list', v);
      case 'getTask':
        return backend.taskAccess('get', v);
      case 'setCheckIn':
        final note = (v['note'] as String? ?? '').trim();
        const endpoint = String.fromEnvironment(
          'MOOD_GATEWAY_URL',
          defaultValue:
              'https://ulexhxfxatzlobabitpr.supabase.co/functions/v1/mood',
        );
        final identityToken = await user.getIdToken();
        if (identityToken == null) throw StateError('Sign in again.');
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $identityToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'spaceId': id,
            'mood': v['mood'],
            'color': v['color'],
            'note': note.length > 180 ? note.substring(0, 180) : note,
          }),
        );
        if (response.statusCode != 200) {
          throw StateError('Could not save your mood. Please try again.');
        }
        return {'ok': true};
      case 'removeCheckIn':
        await space(id!).collection('checkIns').doc(uid).delete();
        return {'ok': true};
      case 'savePlan':
        final planRef = space(id!)
            .collection('plans')
            .doc(v['planId'] as String);
        await db.runTransaction((tx) async {
          final previous = (await tx.get(planRef)).data();
          final parent = (await tx.get(space(id))).data()!;
          if (previous != null &&
              previous['lastMutationId'] == v['operationId']) {
            return;
          }
          if (previous != null &&
              v['expectedRevision'] != null &&
              (previous['revision'] as int? ?? 0) != v['expectedRevision']) {
            throw StateError(
              'This plan changed on another device. Review it before retrying.',
            );
          }
          tx.set(planRef, {
            'ownerUid': uid,
            'title': v['title'],
            'note': v['note'] ?? '',
            'allDay': v['allDay'],
            'startMillis': v['startMillis'],
            'endMillis': v['endMillis'],
            'participants': v['participants'] ?? [],
            'reminder': v['source'] == 'google'
                ? 'none'
                : (v['reminder'] ?? 'none'),
            'revision': (previous?['revision'] as int? ?? 0) + 1,
            if (v['operationId'] != null) 'lastMutationId': v['operationId'],
            if (v['pin'] != null) 'pin': v['pin'],
            if (v['source'] == 'google') ...{
              'source': 'google',
              'sourceCalendarId': v['sourceCalendarId'],
              'sourceEventId': v['sourceEventId'],
              'sourceUpdatedAt': v['sourceUpdatedAt'],
            },
            'updatedAt': FieldValue.serverTimestamp(),
          });
          final revision = (previous?['revision'] as int? ?? 0) + 1;
          addSpaceEvent(
            tx,
            id,
            'plan_${planRef.id}_$revision',
            type: previous == null ? 'planAdded' : 'planChanged',
            entityId: planRef.id,
            planRevision: revision,
            recipients: List<String>.from(parent['memberUids'] as List),
            affectedUids: {
              uid,
              ...List<String>.from(previous?['participants'] as List? ?? []),
              ...List<String>.from(v['participants'] as List? ?? []),
            }.toList(),
          );
        });
        return {'planId': v['planId']};
      case 'removePlan':
        final planRef = space(id!)
            .collection('plans')
            .doc(v['planId'] as String);
        await db.runTransaction((tx) async {
          final previous = (await tx.get(planRef)).data();
          final parent = (await tx.get(space(id))).data()!;
          if (previous == null) return;
          if (v['expectedRevision'] != null &&
              (previous['revision'] as int? ?? 0) != v['expectedRevision']) {
            throw StateError(
              'This plan changed on another device. Review it before retrying.',
            );
          }
          tx.delete(planRef);
          addSpaceEvent(
            tx,
            id,
            'plan_${planRef.id}_${previous['revision']}_removed',
            type: 'planCancelled',
            entityId: planRef.id,
            recipients: List<String>.from(parent['memberUids'] as List),
            affectedUids: {
              uid,
              ...List<String>.from(previous['participants'] as List? ?? []),
            }.toList(),
          );
        });
        return {'removed': true};
      case 'checkInPlanArrival':
        final planId = v['planId'] as String;
        final arrivalEventId = db.collection('eventIds').doc().id;
        await db.runTransaction((tx) async {
          final planRef = space(id!).collection('plans').doc(planId);
          final plan = (await tx.get(planRef)).data();
          final parent = (await tx.get(space(id))).data()!;
          if (plan == null) throw StateError('This plan is unavailable.');
          tx.set(planRef.collection('arrivals').doc(uid), {
            'uid': uid,
            'checkedInAt': FieldValue.serverTimestamp(),
          });
          addSpaceEvent(
            tx,
            id,
            arrivalEventId,
            type: 'planArrival',
            entityId: planId,
            recipients: List<String>.from(parent['memberUids'] as List),
            affectedUids: {
              plan['ownerUid'] as String,
              ...List<String>.from(plan['participants'] as List? ?? []),
            }.toList(),
          );
        });
        return {'ok': true};
      case 'createInvite':
        final spaceRef = space(id!);
        final spaceSnap = await spaceRef.get();
        final data = spaceSnap.data();
        if (data == null || data['ownerUid'] != uid) {
          throw StateError('Only the space owner can invite members.');
        }
        final forceNew = v['forceNew'] == true;
        final existingToken = data['activeInviteToken'] as String?;

        if (!forceNew &&
            existingToken != null &&
            existingToken.trim().isNotEmpty) {
          try {
            final existingSnap = await db.doc('invites/$existingToken').get();
            final existingData = existingSnap.data();
            if (existingData != null &&
                existingData['revoked'] != true &&
                existingData['redeemedUid'] == null &&
                existingData['expiresAt'] is Timestamp &&
                (existingData['expiresAt'] as Timestamp).toDate().isAfter(
                  DateTime.now(),
                )) {
              return {'token': existingToken};
            }
          } on FirebaseException {
            // A stale invite can be replaced below; do not reuse an unreadable one.
          }
        }

        final random = Random.secure();
        const charset = InviteLinks.codeCharset;
        final token = List.generate(
          10,
          (_) => charset[random.nextInt(charset.length)],
        ).join();

        final batch = db.batch();
        final oldInvite = existingToken == null || existingToken.trim().isEmpty
            ? null
            : db.doc('invites/$existingToken');
        if (oldInvite != null && (await oldInvite.get()).exists) {
          batch.update(oldInvite, {'revoked': true});
        }
        batch.set(db.doc('invites/$token'), {
          'spaceId': id,
          'spaceName': data['name'],
          'kind': data['kind'],
          'creatorUid': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            // Stay inside the server rule's seven-day limit even with clock skew.
            DateTime.now().add(const Duration(days: 6)),
          ),
          'redeemedUid': null,
          'revoked': false,
          'requireApproval': data['requireApproval'] == true,
        });
        batch.update(spaceRef, {'activeInviteToken': token});
        await batch.commit();

        return {'token': token};
      case 'previewInvite':
        final token = InviteLinks.sanitize(v['token'] as String);
        final data = (await db.doc('invites/$token').get()).data();
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
      case 'joinSpace':
      case 'redeemInvite':
        final token = InviteLinks.sanitize(v['token'] as String);
        if (!OnlineBackend.useEmulator) {
          return backend.callSpaceAction(
            'join',
            '',
            token: token,
            name: user.displayName,
          );
        }
        final joinEventId = db.collection('eventIds').doc().id;
        String? joined;
        await db.runTransaction((tx) async {
          final invite = db.doc('invites/$token');
          final inviteSnap = await tx.get(invite);
          final data = inviteSnap.data();
          if (data == null ||
              data['revoked'] == true ||
              data['redeemedUid'] != null ||
              (data['expiresAt'] is Timestamp &&
                  (data['expiresAt'] as Timestamp).toDate().isBefore(
                    DateTime.now(),
                  ))) {
            throw StateError(
              'This invitation has expired or was already used. Ask for a new code.',
            );
          }
          joined = data['spaceId'] as String;
          final pending = space(joined!).collection('pendingJoins').doc(uid);
          final pendingSnap = await tx.get(pending);
          if (data['requireApproval'] == true &&
              (pendingSnap.data()?['status'] != 'approved' ||
                  pendingSnap.data()?['token'] != token)) {
            throw StateError('The owner has not approved this request yet.');
          }
          final account = db.doc('accounts/$uid');
          final accountSnap = await tx.get(account);
          final parent = await tx.get(space(joined!));
          final old = accountSnap.data() ?? {};
          if (List.from(old['spaceIds'] ?? []).contains(joined)) return;
          tx.update(invite, {'redeemedUid': uid});
          if (pendingSnap.exists) tx.delete(pending);
          tx.update(space(joined!), {
            'memberUids': FieldValue.arrayUnion([uid]),
            'memberCount': FieldValue.increment(1),
            'joinToken': token,
          });
          addSpaceEvent(
            tx,
            joined!,
            joinEventId,
            type: 'joined',
            entityId: uid,
            targetUid: uid,
            recipients: [
              ...List<String>.from(parent.data()?['memberUids'] as List? ?? []),
              uid,
            ],
          );
          tx.set(space(joined!).collection('members').doc(uid), {
            ...member('member'),
            'joinToken': token,
          });
          tx.set(
            account.collection('spaceRefs').doc(joined),
            reference(joined!, {
              'name': data['spaceName'],
              'kind': data['kind'],
            }),
          );
          final newSpaceIds = [
            ...List<String>.from((old['spaceIds'] as Iterable?) ?? const []),
            joined!,
          ];
          final newOwnedSpaceIds = List<String>.from(
            (old['ownedSpaceIds'] as Iterable?) ?? const [],
          );
          if (accountSnap.exists) {
            tx.update(account, {
              'spaceIds': newSpaceIds,
              'ownedSpaceIds': newOwnedSpaceIds,
              'changedSpaceId': joined,
            });
          } else {
            tx.set(account, {
              'tier': old['tier'] ?? 'basic',
              'spaceIds': newSpaceIds,
              'ownedSpaceIds': newOwnedSpaceIds,
              'changedSpaceId': joined,
            });
          }
        });
        return {'spaceId': joined};
      case 'revokeInvite':
        final token = InviteLinks.sanitize(v['token'] as String);
        await db.doc('invites/$token').update({'revoked': true});
        return {'ok': true};
      case 'removeMember':
      case 'leaveSpace':
        final target = action == 'leaveSpace' ? uid : v['memberUid'] as String;
        final departureEventId = db.collection('eventIds').doc().id;
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
          if (parent['ownerUid'] == target) {
            throw StateError('Transfer ownership before leaving this space.');
          }
          tx.update(space(id), {
            'memberUids': FieldValue.arrayRemove([target]),
            'memberCount': FieldValue.increment(-1),
            'removedUid': target,
          });
          addSpaceEvent(
            tx,
            id,
            departureEventId,
            type: action == 'leaveSpace' ? 'left' : 'removed',
            entityId: target,
            targetUid: target,
            recipients: List<String>.from(parent['memberUids'] as List? ?? [])
              ..remove(target),
          );
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
        final nominee = v['memberUid'] as String;
        final offerEventId = db.collection('eventIds').doc().id;
        await db.runTransaction((tx) async {
          final parent = (await tx.get(space(id!))).data()!;
          tx.update(space(id), {'pendingOwnerUid': nominee});
          addSpaceEvent(
            tx,
            id,
            offerEventId,
            type: 'ownershipOffered',
            entityId: nominee,
            targetUid: nominee,
            recipients: List<String>.from(parent['memberUids'] as List? ?? []),
          );
        });
        return {'ok': true};
      case 'cancelOwnership':
        final cancelledEventId = db.collection('eventIds').doc().id;
        await db.runTransaction((tx) async {
          final parent = (await tx.get(space(id!))).data()!;
          final nominee = parent['pendingOwnerUid'] as String?;
          if (parent['ownerUid'] != uid)
            throw StateError('Only the owner can cancel this offer.');
          if (nominee == null) return;
          tx.update(space(id), {'pendingOwnerUid': null});
          addSpaceEvent(
            tx,
            id,
            cancelledEventId,
            type: 'ownershipCancelled',
            entityId: nominee,
            targetUid: nominee,
            recipients: List<String>.from(parent['memberUids'] as List? ?? []),
          );
        });
        return {'ok': true};
      case 'acceptOwnership':
        final acceptEventId = db.collection('eventIds').doc().id;
        await db.runTransaction((tx) async {
          final parent = (await tx.get(space(id!))).data()!;
          tx.update(space(id), {'ownerUid': uid, 'pendingOwnerUid': null});
          addSpaceEvent(
            tx,
            id,
            acceptEventId,
            type: 'ownershipAccepted',
            entityId: uid,
            targetUid: uid,
            recipients: List<String>.from(parent['memberUids'] as List? ?? []),
          );
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
      case 'deleteSpace':
        final spaceRef = space(id!);
        await db.runTransaction((tx) async {
          final spaceSnap = await tx.get(spaceRef);
          if (!spaceSnap.exists) return;
          final sData = spaceSnap.data()!;
          if (sData['ownerUid'] != uid) {
            throw StateError('Only the space owner can delete this space.');
          }
          final memberUids = List<String>.from(
            (sData['memberUids'] as Iterable?) ?? [uid],
          );
          tx.set(db.doc('spaceDeletionJobs/$id'), {
            'requestedBy': uid,
            'spaceName': sData['name'],
            'memberUids': memberUids,
            'status': 'pending',
            'requestedAt': FieldValue.serverTimestamp(),
          });
          for (final mUid in memberUids) {
            final accRef = db.doc('accounts/$mUid');
            tx.update(accRef, {
              'spaceIds': FieldValue.arrayRemove([id]),
              'ownedSpaceIds': FieldValue.arrayRemove([id]),
              'changedSpaceId': id,
            });
            tx.delete(accRef.collection('spaceRefs').doc(id));
          }
          tx.update(spaceRef, {
            'memberUids': <String>[],
            'memberCount': 0,
            'ownerUid': null,
            'deletionStatus': 'pending',
            'deletionRequestedAt': FieldValue.serverTimestamp(),
          });
        });
        return {'status': 'pending'};
      case 'updateTask':
        final taskId = v['taskId'] as String;
        var savedVersion = 0;
        final updates = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (v.containsKey('title')) {
          updates['title'] = checkedTaskName(v['title'] as String);
        }
        if (v.containsKey('note')) {
          updates['note'] = (v['note'] as String).trim();
        }
        if (v.containsKey('destination')) {
          updates['destination'] = (v['destination'] as String).trim();
        }
        if (v.containsKey('requestedUid')) {
          updates['requestedUid'] = v['requestedUid'];
        }
        if (v.containsKey('subtasks')) {
          updates['subtasks'] = v['subtasks'];
        }
        if (v.containsKey('helpNeeded')) {
          updates['helpNeeded'] = v['helpNeeded'];
        }
        if (v.containsKey('activity')) {
          updates['activity'] = v['activity'];
        }
        final assignmentEventId = db.collection('eventIds').doc().id;
        await db.runTransaction((tx) async {
          final taskRef = space(id!).collection('tasks').doc(taskId);
          final before = await tx.get(taskRef);
          final parent = await tx.get(space(id));
          if (!before.exists) {
            throw StateError('This task is no longer available.');
          }
          if (v['expectedVersion'] != null &&
              v['expectedVersion'] != before.data()?['version']) {
            throw StateError(
              'This task changed on another device. Reopen it before saving.',
            );
          }
          savedVersion = (before.data()?['version'] as int? ?? 0) + 1;
          updates['version'] = savedVersion;
          final nextRecipient = updates['requestedUid'] as String?;
          if (v.containsKey('requestedUid') &&
              nextRecipient == null &&
              before.data()?['requestedUid'] != null) {
            if (before.data()?['status'] != 'requested') {
              throw StateError('Use a handoff to change who covers this task.');
            }
            updates['status'] = 'unclaimed';
            updates['version'] = (before.data()?['version'] as int? ?? 0) + 1;
          }
          if (nextRecipient != null &&
              nextRecipient != before.data()?['requestedUid']) {
            if (![
              'unclaimed',
              'requested',
            ].contains(before.data()?['status'])) {
              throw StateError('Use a handoff to change who covers this task.');
            }
            updates['status'] = 'requested';
            updates['version'] = (before.data()?['version'] as int? ?? 0) + 1;
            addSpaceEvent(
              tx,
              id,
              assignmentEventId,
              type: 'taskAssigned',
              entityId: taskId,
              taskVersion: updates['version'] as int,
              targetUid: nextRecipient,
              recipients: List<String>.from(
                parent.data()?['memberUids'] as List? ?? [],
              ),
            );
          }
          final contentChanged = ['title', 'note', 'destination'].any(
            (field) =>
                updates.containsKey(field) &&
                updates[field] != (before.data()?[field] ?? ''),
          );
          if (contentChanged && updates['status'] != 'requested') {
            addSpaceEvent(
              tx,
              id,
              assignmentEventId,
              type: 'taskEdited',
              entityId: taskId,
              recipients: List<String>.from(
                parent.data()?['memberUids'] as List? ?? [],
              ),
              affectedUids: {
                for (final value in [
                  before.data()?['creatorUid'],
                  before.data()?['ownerUid'],
                  before.data()?['requestedUid'],
                  before.data()?['offeredUid'],
                ])
                  if (value is String) value,
              }.toList(),
            );
          }
          tx.update(taskRef, updates);
        });
        return {'ok': true, 'version': savedVersion};
      case 'deleteTask':
        return backend.taskAccess('delete', v);
      case 'setSubtasks':
        final taskId = v['taskId'] as String;
        await space(id!).collection('tasks').doc(taskId).update({
          'subtasks': v['subtasks'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return {'ok': true};
      case 'requestHelp':
        final sId = id!;
        final taskId = v['taskId'] as String;
        final helpEventId = db.collection('eventIds').doc().id;
        await db.runTransaction((tx) async {
          final taskRef = space(sId).collection('tasks').doc(taskId);
          final taskDoc = await tx.get(taskRef);
          final parent = await tx.get(space(sId));
          if (taskDoc.data()?['helpNeeded'] == true) return;
          final currentActivity = List<Map<String, dynamic>>.from(
            taskDoc.data()?['activity'] as List? ?? [],
          );
          currentActivity.insert(0, {
            'action': 'help_requested',
            'uid': uid,
            'name': user.displayName ?? 'Member',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          tx.update(taskRef, {
            'helpNeeded': true,
            'activity': currentActivity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          addSpaceEvent(
            tx,
            sId,
            helpEventId,
            type: 'helpRequested',
            entityId: taskId,
            recipients: List<String>.from(
              parent.data()?['memberUids'] as List? ?? [],
            ),
          );
        });
        return {'ok': true};
      case 'takeOverTask':
        final sId = id!;
        final taskId = v['taskId'] as String;
        final takeoverEventId = db.collection('eventIds').doc().id;
        await db.runTransaction((tx) async {
          final taskRef = space(sId).collection('tasks').doc(taskId);
          final taskDoc = await tx.get(taskRef);
          final parent = await tx.get(space(sId));
          if (taskDoc.data()?['ownerUid'] == uid) return;
          final currentActivity = List<Map<String, dynamic>>.from(
            taskDoc.data()?['activity'] as List? ?? [],
          );
          currentActivity.insert(0, {
            'action': 'taken_over',
            'uid': uid,
            'name': user.displayName ?? 'Member',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          tx.update(taskRef, {
            'ownerUid': uid,
            'requestedUid': null,
            'helpNeeded': false,
            'activity': currentActivity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          addSpaceEvent(
            tx,
            sId,
            takeoverEventId,
            type: 'covered',
            entityId: taskId,
            targetUid: taskDoc.data()?['creatorUid'] as String?,
            recipients: List<String>.from(
              parent.data()?['memberUids'] as List? ?? [],
            ),
            affectedUids: {
              for (final value in [
                taskDoc.data()?['creatorUid'],
                taskDoc.data()?['ownerUid'],
                taskDoc.data()?['requestedUid'],
                taskDoc.data()?['offeredUid'],
              ])
                if (value is String) value,
            }.toList(),
          );
        });
        return {'ok': true};
      case 'createDependentProfile':
        throw StateError(
          'Dependent profiles are unavailable in the adult-only pilot.',
        );
      case 'updateDependentProfile':
        final sId = id!;
        final memberId = v['memberId'] as String;
        await space(sId).collection('members').doc(memberId).update({
          'name': (v['name'] as String).trim(),
          'familyRole': v['familyRole'] ?? 'Child',
          'color': v['color'] ?? 'sky',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return {'memberId': memberId};
      case 'deleteDependentProfile':
        final sId = id!;
        final memberId = v['memberId'] as String;
        await space(sId).collection('members').doc(memberId).delete();
        return {'ok': true};
      case 'setJoinApprovalPolicy':
        final sId = id!;
        final requireApproval = v['requireApproval'] == true;
        final current =
            (await space(sId).get()).data()?['activeInviteToken'] as String?;
        final batch = db.batch();
        batch.update(space(sId), {'requireApproval': requireApproval});
        if (current != null) {
          batch.update(db.doc('invites/$current'), {
            'requireApproval': requireApproval,
          });
        }
        await batch.commit();
        return {'ok': true};
      case 'requestJoinSpace':
        final sId = id!;
        final token = InviteLinks.sanitize(v['token'] as String);
        final pendingRef = space(sId).collection('pendingJoins').doc(uid);
        final prior = await pendingRef.get();
        if (prior.data()?['status'] == 'approved' &&
            prior.data()?['token'] == token) {
          return {'approved': true};
        }
        if (prior.exists) {
          if (prior.data()?['token'] == token) {
            if (prior.data()?['status'] == 'declined') {
              throw StateError(
                'This join request was declined. Ask the owner for a new invitation.',
              );
            }
            return {'approved': false};
          }
          await pendingRef.delete();
        }
        await pendingRef.set({
          'uid': uid,
          'name': user.displayName ?? 'Member',
          'email': user.email ?? '',
          'token': token,
          'status': 'pending',
          'requestedAt': FieldValue.serverTimestamp(),
        });
        return {'ok': true};
      case 'approveJoinRequest':
        final sId = id!;
        final targetUid = v['targetUid'] as String;
        await space(sId)
            .collection('pendingJoins')
            .doc(targetUid)
            .update({'status': 'approved'});
        return {'ok': true};
      case 'declineJoinRequest':
        final sId = id!;
        final targetUid = v['targetUid'] as String;
        await space(sId)
            .collection('pendingJoins')
            .doc(targetUid)
            .update({'status': 'declined'});
        return {'ok': true};
      case 'createRoutine':
        final ref = space(id!).collection('routines').doc();
        final title = (v['title'] as String).trim();
        final cadence = v['cadence'] as String? ?? 'daily';
        if (title.isEmpty ||
            title.length > 120 ||
            !['daily', 'weekdays', 'weekly'].contains(cadence)) {
          throw ArgumentError('Check the routine title and repeat schedule.');
        }
        await db.runTransaction((tx) async {
          final parent = await tx.get(space(id));
          final count = parent.data()?['routineCount'] as int? ?? 0;
          if (count >= 5) {
            throw StateError('This space has five routines already.');
          }
          tx.set(ref, {
            'id': ref.id,
            'title': title,
            'cadence': cadence,
            'assignedUid': v['assignedUid'],
            'creatorUid': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(space(id), {
            'routineCount': count + 1,
            'changedRoutineId': ref.id,
          });
        });
        return {'routineId': ref.id};
      case 'deleteRoutine':
        final routineId = v['routineId'] as String;
        await db.runTransaction((tx) async {
          final ref = space(id!).collection('routines').doc(routineId);
          final routine = await tx.get(ref);
          if (!routine.exists) return;
          final parent = await tx.get(space(id));
          final count = parent.data()?['routineCount'] as int? ?? 0;
          tx.delete(ref);
          tx.update(space(id), {
            'routineCount': count > 0 ? count - 1 : 0,
            'changedRoutineId': routineId,
          });
        });
        return {'ok': true};
      case 'toggleReaction':
        final momentId = v['momentId'] as String;
        final reactionType = v['reactionType'] as String;
        final reactionRef = space(id!)
            .collection('moments')
            .doc(momentId)
            .collection('reactions')
            .doc(uid);
        final snap = await reactionRef.get();
        final selected = snap.data()?['type'] == reactionType;
        await backend.callMediaAction({
          'action': 'react',
          'space': id,
          'id': momentId,
          'type': selected ? null : reactionType,
        });
        return {'active': !selected};
      case 'startLocationSession':
        final durationMinutes = (v['durationMinutes'] as int?) ?? 15;
        if (![15, 30, 60].contains(durationMinutes)) {
          throw ArgumentError('Choose a sharing duration.');
        }
        if (!OnlineBackend.useEmulator) {
          return backend.callSpaceAction(
            'startLocation',
            id!,
            name: user.displayName,
            location: {
              'lat': v['lat'],
              'lng': v['lng'],
              'accuracy': v['accuracy'],
              'durationMinutes': durationMinutes,
            },
          );
        }
        final spaceSnap = await space(id!).get();
        final recipients = List<String>.from(
          spaceSnap.data()?['memberUids'] as List? ?? const [],
        );
        if (!recipients.contains(uid)) {
          throw StateError('You are no longer in this space.');
        }
        final expiresAt = DateTime.now().toUtc().add(
          Duration(minutes: durationMinutes),
        );
        final session = space(id).collection('locationSessions').doc(uid);
        // Owners may delete their own session even when absent/expired, but
        // recipient reads require an unexpired document. Do not read first.
        await session.delete();
        await session.set({
          'uid': uid,
          'name': String.fromCharCodes(
            (user.displayName ?? 'Member').runes.take(60),
          ),
          'lat': (v['lat'] as num).toDouble(),
          'lng': (v['lng'] as num).toDouble(),
          'accuracy': (v['accuracy'] as num).toDouble(),
          'recipientUids': recipients,
          'durationMinutes': durationMinutes,
          'startedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
        });
        return {'ok': true, 'expiresAt': expiresAt.toIso8601String()};
      case 'updateLocation':
        await space(id!).collection('locationSessions').doc(uid).update({
          'lat': (v['lat'] as num).toDouble(),
          'lng': (v['lng'] as num).toDouble(),
          'accuracy': (v['accuracy'] as num).toDouble(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return {'ok': true};
      case 'stopLocationSession':
        if (!OnlineBackend.useEmulator)
          return backend.callSpaceAction('stopLocation', id!);
        await space(id!).collection('locationSessions').doc(uid).delete();
        return {'ok': true};
      case 'checkInArrival':
        final taskId = v['taskId'] as String;
        final arrivalEventId = db.collection('eventIds').doc().id;
        await db.runTransaction((tx) async {
          final taskRef = space(id!).collection('tasks').doc(taskId);
          final task = (await tx.get(taskRef)).data();
          final parent = (await tx.get(space(id))).data()!;
          if (task == null) throw StateError('This task is unavailable.');
          tx.set(taskRef.collection('arrivals').doc(uid), {
            'uid': uid,
            'checkedInAt': FieldValue.serverTimestamp(),
          });
          addSpaceEvent(
            tx,
            id,
            arrivalEventId,
            type: 'taskArrival',
            entityId: taskId,
            recipients: List<String>.from(parent['memberUids'] as List),
            affectedUids: {
              for (final value in [
                task['creatorUid'],
                task['ownerUid'],
                task['requestedUid'],
                task['offeredUid'],
              ])
                if (value is String) value,
            }.toList(),
          );
        });
        return {'ok': true};
      default:
        throw StateError('This action is not available.');
    }
  }
}
