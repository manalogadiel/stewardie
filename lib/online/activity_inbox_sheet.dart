import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'online_backend.dart';
import '../core/member_avatar.dart';
import '../core/theme.dart';

/// Task requests remain visible even if scheduled notifications are unavailable.
class ActivityInboxSheet extends StatelessWidget {
  const ActivityInboxSheet({
    super.key,
    required this.backend,
    required this.spaceNames,
    this.onOpenSpace,
    this.onOpenTask,
    this.onOpenOwnership,
    this.requests = const [],
  });

  final OnlineBackend backend;
  final Map<String, String> spaceNames;
  final Future<void> Function(String spaceId)? onOpenSpace;
  final Future<void> Function(String spaceId, String taskId)? onOpenTask;
  final Future<void> Function(String spaceId)? onOpenOwnership;
  final List<Widget> requests;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required Map<String, String> spaceNames,
    List<Widget> requests = const [],
  }) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ActivityInboxSheet(
      backend: backend,
      spaceNames: spaceNames,
      requests: requests,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final uid = backend.auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final collection = backend.firestore.collection('accounts/$uid/activity');
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: collection
            .orderBy('createdAt', descending: true)
            .limit(60)
            .snapshots(),
        builder: (context, snapshot) {
          final items = (snapshot.data?.docs ?? [])
              .where(
                (doc) =>
                    doc.data()['pushState'] != 'cancelled' &&
                    spaceNames.containsKey(doc.data()['spaceId']),
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (snapshot.hasError)
                const ListTile(
                  title: Text('Could not load activity. Try again later.'),
                ),
              if (!snapshot.hasError &&
                  snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(),
              ...requests,
              if (items.isEmpty &&
                  requests.isEmpty &&
                  !snapshot.hasError &&
                  snapshot.hasData)
                const ListTile(title: Text('You’re all caught up.')),
              for (final doc in items) _historyItem(context, doc, uid),
            ],
          );
        },
      ),
    );
  }

  Widget _historyItem(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String uid,
  ) {
    final data = doc.data();
    final spaceId = data['spaceId'] as String?;
    final kind = data['kind'];
    if (spaceId != null &&
        (kind == 'taskAssigned' || kind == 'action') &&
        data['taskId'] is String) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: backend.firestore
            .doc('spaces/$spaceId/tasks/${data['taskId']}')
            .snapshots(),
        builder: (context, snapshot) {
          final task = snapshot.data?.data();
          final pending =
              task != null &&
              (data['taskVersion'] == null ||
                  data['taskVersion'] == task['version']) &&
              ((task['status'] == 'requested' && task['requestedUid'] == uid) ||
                  (task['offeredUid'] != null && task['ownerUid'] == uid));
          return pending ? const SizedBox.shrink() : _historyTile(context, doc);
        },
      );
    }
    if (spaceId != null && kind == 'ownershipOffered') {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: backend.firestore.doc('spaces/$spaceId').snapshots(),
        builder: (context, snapshot) =>
            snapshot.data?.data()?['pendingOwnerUid'] == uid
            ? const SizedBox.shrink()
            : _historyTile(context, doc),
      );
    }
    return _historyTile(context, doc);
  }

  Widget _historyTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: _eventAvatar(doc.data()),
      tileColor: doc.data()['readAt'] == null
          ? SoftPop.blueSoft.withValues(alpha: .45)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        doc.data()['title'] as String? ?? 'Activity',
        style: TextStyle(
          fontWeight: doc.data()['readAt'] == null
              ? FontWeight.w800
              : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        [
          spaceNames[doc.data()['spaceId']] ?? 'Space',
          doc.data()['body'] as String? ?? '',
          if (doc.data()['createdAt'] is Timestamp)
            '${MaterialLocalizations.of(context).formatMediumDate((doc.data()['createdAt'] as Timestamp).toDate().toLocal())} '
                '${TimeOfDay.fromDateTime((doc.data()['createdAt'] as Timestamp).toDate().toLocal()).format(context)}',
        ].where((text) => text.isNotEmpty).join(' · '),
      ),
      onTap: () async {
        if (doc.data()['readAt'] == null) {
          try {
            await doc.reference.update({
              'readAt': FieldValue.serverTimestamp(),
            });
          } catch (_) {
            // A temporary read-state sync failure must not block navigation.
          }
        }
        final spaceId = doc.data()['spaceId'] as String?;
        if (spaceId == null || !spaceNames.containsKey(spaceId)) return;
        final kind = doc.data()['kind'] as String?;
        final taskId =
            (doc.data()['taskId'] ?? doc.data()['entityId']) as String?;
        if (taskId != null &&
            [
              'taskAssigned',
              'action',
              'helpRequested',
              'covered',
              'completed',
              'due',
            ].contains(kind) &&
            onOpenTask != null) {
          await onOpenTask!(spaceId, taskId);
        } else if (kind == 'ownershipOffered' && onOpenOwnership != null) {
          await onOpenOwnership!(spaceId);
        } else {
          await onOpenSpace?.call(spaceId);
        }
      },
    ),
  );

  Widget _eventAvatar(Map<String, dynamic> item) {
    final actorUid = item['actorUid'] as String?;
    final spaceId = item['spaceId'] as String?;
    if (actorUid == null || spaceId == null) {
      return Icon(
        item['readAt'] == null
            ? Icons.notifications_active_rounded
            : Icons.notifications_none_rounded,
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: backend.firestore
          .doc('spaces/$spaceId/members/$actorUid')
          .snapshots(),
      builder: (context, snapshot) => MemberAvatar(
        uid: actorUid,
        name: snapshot.data?.data()?['name'] as String? ?? 'Former member',
      ),
    );
  }
}
