/// A live request and its later worker-created notice represent one alert.
String? liveRequestKey(
  String spaceId,
  String taskId,
  String uid,
  Map<String, dynamic> task,
) {
  if ((task['status'] == 'requested' && task['requestedUid'] == uid) ||
      (task['offeredUid'] != null && task['ownerUid'] == uid)) {
    return 'task:$spaceId:$taskId:${task['version'] ?? 'legacy'}';
  }
  return null;
}

String? unreadActivityKey(String id, Map<String, dynamic> item) {
  if (item['pushState'] == 'cancelled') return null;
  final spaceId = item['spaceId'] as String?;
  if (spaceId == null) return null;
  final kind = item['kind'] as String?;
  final taskId =
      item['taskId'] as String? ??
      (['taskAssigned', 'helpRequested', 'covered', 'completed'].contains(kind)
          ? item['entityId'] as String?
          : null);
  if (taskId != null && (kind == 'action' || kind == 'taskAssigned')) {
    return 'task:$spaceId:$taskId:${item['taskVersion'] ?? 'legacy'}';
  }
  if (kind == 'ownershipOffered') return 'ownership:$spaceId';
  return 'activity:$id';
}

int uniqueNotificationCount(
  Iterable<Set<String>> live,
  Iterable<Set<String>> history,
) {
  final keys = {
    for (final set in live) ...set,
    for (final set in history) ...set,
  };
  // Earlier events had no version. A live request supersedes the legacy
  // alert for the same task without collapsing newer versions.
  final superseded = keys
      .where(
        (key) =>
            key.endsWith(':legacy') &&
            keys.any(
              (other) =>
                  other != key &&
                  other.startsWith(
                    key.substring(0, key.length - 'legacy'.length),
                  ),
            ),
      )
      .toList();
  keys.removeAll(superseded);
  return keys.length;
}
