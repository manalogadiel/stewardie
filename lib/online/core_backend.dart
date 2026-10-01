import 'core_firestore.dart';
import 'online_backend.dart';
import 'core_data_client.dart';

class CoreBackend {
  CoreBackend(this.backend);
  final OnlineBackend backend;
  final _requests = <String, Map<String, dynamic>>{};
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> values,
  ) async {
    final user = backend.auth.currentUser;
    if (user?.emailVerified != true) {
      throw StateError('Sign in with a verified email first.');
    }
    final uid = user!.uid;
    final op = values['operationId'] as String? ?? backend.newOperationId();
    final sid = values['spaceId'] as String?;
    final payload = <String, dynamic>{...values, 'operationId': op};
    Map<String, dynamic> decode(Map<String, dynamic> data) =>
        Map<String, dynamic>.from(coreDecode(data) as Map);
    Future<Map<String, dynamic>> rpc(
      String action,
      Map<String, dynamic> data,
    ) async {
      late final Map<String, dynamic> result;
      try {
        result = await backend.coreData.call(action, data);
      } on CoreDataException catch (error) {
        // A rejected version has no receipt. A user's next retry can reread it;
        // uncertain network errors retain the original version for safe replay.
        if (error.statusCode == 409 &&
            error.message.contains('This task changed')) {
          _requests.remove('$uid/$op');
        }
        rethrow;
      }
      if (backend.auth.currentUser?.uid != uid) {
        throw StateError('Sign in again.');
      }
      backend.coreStore.notify();
      return decode(result);
    }

    switch (action) {
      case 'createSpace':
        return rpc(action, {
          ...payload,
          'displayName': user.displayName ?? 'Member',
        });
      case 'createInvite':
        final result = await rpc(action, payload);
        return {...result, 'token': result['code']};
      case 'previewInvite':
        final result = await rpc(action, {'code': values['token']});
        return {...result, 'spaceName': result['name']};
      case 'joinSpace':
      case 'redeemInvite':
        return rpc('joinSpace', {
          'code': values['token'],
          'displayName': user.displayName ?? 'Member',
          'operationId': op,
        });
      case 'requestJoinSpace':
        final result = await rpc('requestJoin', {
          'code': values['token'],
          'displayName': user.displayName ?? 'Member',
          'operationId': op,
        });
        return {...result, 'approved': result['alreadyJoined'] == true};
      case 'approveJoinRequest':
      case 'declineJoinRequest':
        return rpc('resolveJoin', {
          'spaceId': sid,
          'memberUid': values['targetUid'],
          'decision': action == 'approveJoinRequest' ? 'approve' : 'reject',
          'operationId': op,
        });
      case 'revokeInvite':
        return rpc(action, {...payload, 'code': values['token']});
      case 'createTask':
        return rpc(action, payload);
      case 'getTask':
        return {
          'task': decode(
            await backend.coreTasks.get(sid!, values['taskId'] as String),
          ),
        };
      case 'listCompletedTasks':
        String? beforeId, beforeTime;
        if (values['cursorId'] is String) {
          final cursor = await backend.coreTasks.get(
            sid!,
            values['cursorId'] as String,
          );
          beforeId = cursor['id'] as String;
          beforeTime = cursor['updatedAt'] as String;
        }
        final tasks = <Map<String, dynamic>>[];
        for (
          var pageNumber = 0;
          pageNumber < 10 && tasks.length < 50;
          pageNumber++
        ) {
          final page = await backend.coreTasks.list(
            sid!,
            beforeId: beforeId,
            beforeTime: beforeTime,
            limit: 100,
          );
          for (final task in page.tasks) {
            if (task['status'] == 'completed' &&
                (values['personUid'] == null ||
                    task['ownerUid'] == values['personUid'])) {
              tasks.add(task);
            }
            if (tasks.length == 50) break;
          }
          beforeId = page.nextId;
          beforeTime = page.nextTime;
          if (beforeId == null) break;
        }
        return {
          'tasks': tasks.map(decode).toList(),
          'nextCursorId': tasks.length == 50 ? tasks.last['id'] : beforeId,
        };
      case 'actOnTask':
      case 'markTaskDone':
      case 'updateTask':
      case 'deleteTask':
      case 'setSubtasks':
        // Pin the first observed version across retrying a lost acknowledgement.
        final key = '$uid/$op';
        final request =
            _requests[key] ??
            await (() async {
              final task = values['expectedVersion'] == null
                  ? await backend.coreTasks.get(
                      sid!,
                      values['taskId'] as String,
                    )
                  : const <String, dynamic>{};
              return {
                ...payload,
                'expectedVersion': values['expectedVersion'] ?? task['version'],
              };
            })();
        _requests[key] = request;
        if (action == 'updateTask') {
          const editable = {
            'title',
            'note',
            'notes',
            'destination',
            'pin',
            'requestedUid',
            'subtasks',
            'scheduledLocalDate',
          };
          return rpc(action, {
            'spaceId': sid,
            'taskId': values['taskId'],
            'operationId': op,
            'expectedVersion': request['expectedVersion'],
            'patch': {
              for (final entry in values.entries)
                if (editable.contains(entry.key)) entry.key: entry.value,
            },
          });
        }
        return rpc(action == 'markTaskDone' ? 'actOnTask' : action, {
          ...request,
          if (action == 'markTaskDone') 'action': 'complete',
        });
      case 'setCheckIn':
      case 'removeCheckIn':
        await backend.coreData.call('docWrite', {
          'path': 'spaces/$sid/checkIns/$uid',
          'mode': action == 'removeCheckIn' ? 'delete' : 'set',
          'data': {...values, 'uid': uid, 'name': user.displayName ?? 'Member'},
        });
        backend.coreStore.notify();
        return {'ok': true};
      case 'checkInArrival':
      case 'checkInPlanArrival':
      case 'savePlan':
      case 'removePlan':
      case 'createRoutine':
      case 'deleteRoutine':
      case 'requestHelp':
      case 'takeOverTask':
      case 'startLocationSession':
      case 'updateLocation':
      case 'stopLocationSession':
        return rpc(action, {
          ...payload,
          'displayName': user.displayName ?? 'Member',
        });
      case 'toggleReaction':
        final snap = await backend.firestore
            .doc('spaces/$sid/moments/${values['momentId']}/reactions/$uid')
            .get();
        final selected = snap.data()?['type'] == values['reactionType'];
        await backend.callMediaAction({
          'action': 'react',
          'space': sid,
          'id': values['momentId'],
          'type': selected ? null : values['reactionType'],
        });
        backend.coreStore.notify();
        return {'active': !selected};
      case 'createDependentProfile':
      case 'updateDependentProfile':
      case 'deleteDependentProfile':
        throw StateError(
          'Dependent profiles are unavailable in the adult-only pilot.',
        );
      default:
        return rpc(action, payload);
    }
  }
}
