import 'dart:async';

import 'core_data_client.dart';

/// Typed Supabase space operations using the retained Firebase identity.
/// Callers retain each operation ID across retries and persist the selected ID.
class CoreSpaceRepository {
  CoreSpaceRepository(this.client);
  final CoreDataClient client;

  Future<List<Map<String, dynamic>>> listSpaces() async {
    final result = await client.call('listSpaces');
    final values = result['spaces'];
    if (values is! List ||
        values.any((value) => value is! Map<String, dynamic>)) {
      throw const CoreDataException('Invalid space list.', 503);
    }
    return values.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getSpace(String spaceId) =>
      client.call('getSpace', {'spaceId': spaceId});

  Future<Map<String, dynamic>> previewInvite(String code) =>
      client.call('previewInvite', {'code': code.trim()});

  Future<String> createAndSelect({
    required String name,
    required String displayName,
    required String operationId,
    required FutureOr<void> Function(String) selectSpace,
    String kind = 'other',
    String timeZone = 'Asia/Manila',
  }) async {
    final result = await client.call('createSpace', {
      'name': name.trim(),
      'displayName': displayName,
      'kind': kind,
      'timeZone': timeZone,
      'operationId': operationId,
    });
    final id = _spaceId(result);
    await selectSpace(id);
    return id;
  }

  Future<String> joinAndSelect({
    required String code,
    required String displayName,
    required String operationId,
    required FutureOr<void> Function(String) selectSpace,
  }) async {
    final result = await client.call('joinSpace', {
      'code': code.trim(),
      'displayName': displayName,
      'operationId': operationId,
    });
    final id = _spaceId(result);
    await selectSpace(id);
    return id;
  }

  // A pending approval is not membership and must never select that space.
  Future<Map<String, dynamic>> requestJoin({
    required String code,
    required String displayName,
    required String operationId,
  }) => client.call('requestJoin', {
    'code': code.trim(),
    'displayName': displayName,
    'operationId': operationId,
  });

  Future<Map<String, dynamic>> manage({
    required String action,
    required String spaceId,
    required String operationId,
    String? name,
    String? memberUid,
    String? code,
    String? decision,
    bool? requireApproval,
  }) {
    const actions = {
      'renameSpace',
      'createInvite',
      'revokeInvite',
      'resolveJoin',
      'leaveSpace',
      'removeMember',
      'offerOwnership',
      'cancelOwnership',
      'acceptOwnership',
      'deleteSpace',
      'setJoinApprovalPolicy',
    };
    if (!actions.contains(action)) {
      throw ArgumentError.value(action, 'action', 'Unsupported space action');
    }
    return client.call(action, {
      'spaceId': spaceId,
      'operationId': operationId,
      if (name != null) 'name': name.trim(),
      'memberUid': ?memberUid,
      if (code != null) 'code': code.trim(),
      'decision': ?decision,
      'requireApproval': ?requireApproval,
    });
  }

  String _spaceId(Map<String, dynamic> result) {
    final id = result['spaceId'];
    if (id is! String || id.isEmpty || result['pending'] == true) {
      throw const CoreDataException('Space access is not ready.', 503);
    }
    return id;
  }
}
