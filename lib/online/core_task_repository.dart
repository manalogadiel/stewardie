import 'core_data_client.dart';

class CoreTaskPage {
  const CoreTaskPage(this.tasks, this.nextTime, this.nextId);
  final List<Map<String, dynamic>> tasks;
  final String? nextTime, nextId;
}

/// Staged, explicit pagination and versioned mutations; no Firestore fallback.
class CoreTaskRepository {
  CoreTaskRepository(this.client);
  final CoreDataClient client;

  Future<CoreTaskPage> list(
    String spaceId, {
    String? beforeTime,
    String? beforeId,
    int limit = 50,
  }) async {
    final result = await client.call('listTasks', {
      'spaceId': spaceId,
      'beforeTime': ?beforeTime,
      'beforeId': ?beforeId,
      'limit': limit,
    });
    final rows = result['tasks'];
    if (rows is! List) throw const CoreDataException('Invalid task list.', 503);
    final tasks = rows.map(_task).toList();
    // An exactly full page may have an empty successor. Never assume it ends.
    final hasMore = tasks.length >= limit.clamp(1, 100);
    return CoreTaskPage(
      tasks,
      hasMore ? tasks.last['updatedAt'] as String : null,
      hasMore ? tasks.last['id'] as String : null,
    );
  }

  Future<Map<String, dynamic>> get(String spaceId, String taskId) async =>
      _task(
        (await client.call('getTask', {
          'spaceId': spaceId,
          'taskId': taskId,
        }))['task'],
      );

  Future<Map<String, dynamic>> create({
    required String spaceId,
    required String title,
    required String operationId,
    required String scheduledLocalDate,
    String? requestedUid,
    Map<String, dynamic>? pin,
    String notes = '',
  }) => client.call('createTask', {
    'spaceId': spaceId,
    'title': title.trim(),
    'operationId': operationId,
    'scheduledLocalDate': scheduledLocalDate,
    'requestedUid': ?requestedUid,
    'pin': ?pin,
    'notes': notes,
  });

  Future<Map<String, dynamic>> update({
    required String spaceId,
    required String taskId,
    required int expectedVersion,
    required String operationId,
    required Map<String, dynamic> patch,
  }) => client.call('updateTask', {
    'spaceId': spaceId,
    'taskId': taskId,
    'expectedVersion': expectedVersion,
    'operationId': operationId,
    'patch': patch,
  });

  Future<Map<String, dynamic>> act({
    required String spaceId,
    required String taskId,
    required int expectedVersion,
    required String operationId,
    required String action,
  }) => client.call('actOnTask', {
    'spaceId': spaceId,
    'taskId': taskId,
    'expectedVersion': expectedVersion,
    'operationId': operationId,
    'action': action,
  });

  Future<Map<String, dynamic>> delete({
    required String spaceId,
    required String taskId,
    required int expectedVersion,
    required String operationId,
  }) => client.call('deleteTask', {
    'spaceId': spaceId,
    'taskId': taskId,
    'expectedVersion': expectedVersion,
    'operationId': operationId,
  });

  Map<String, dynamic> _task(dynamic raw) {
    if (raw is! Map<String, dynamic> ||
        raw['id'] is! String ||
        raw['version'] is! int ||
        raw['updatedAt'] is! String) {
      throw const CoreDataException('Invalid task response.', 503);
    }
    final details = raw['details'];
    if (details != null && details is! Map<String, dynamic>) {
      throw const CoreDataException('Invalid task details.', 503);
    }
    // Trusted columns always override imported nested data.
    final task = {...?details as Map<String, dynamic>?, ...raw}
      ..remove('details');
    // Existing task sheets use `note`; timeline models use `notes`.
    task['notes'] = task['note'] ?? task['notes'] ?? '';
    task['note'] = task['notes'];
    return task;
  }
}
