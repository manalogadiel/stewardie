import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'online_backend.dart';

/// Task requests remain visible even if scheduled notifications are unavailable.
class ActivityInboxSheet extends StatelessWidget {
  const ActivityInboxSheet({
    super.key,
    required this.backend,
    required this.spaceNames,
    this.onOpenSpace,
    this.requests = const [],
  });

  final OnlineBackend backend;
  final Map<String, String> spaceNames;
  final ValueChanged<String>? onOpenSpace;
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
              .where((doc) => doc.data()['pushState'] != 'cancelled' &&
                  spaceNames.containsKey(doc.data()['spaceId']))
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

  Widget _historyItem(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    final data = doc.data();
    final spaceId = data['spaceId'] as String?;
    final kind = data['kind'];
    if (spaceId != null && (kind == 'taskAssigned' || kind == 'action') && data['taskId'] is String) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: backend.firestore.doc('spaces/$spaceId/tasks/${data['taskId']}').snapshots(),
        builder: (context, snapshot) {
          final task = snapshot.data?.data();
          final pending = task != null &&
              ((task['status'] == 'requested' && task['requestedUid'] == uid) ||
               (task['offeredUid'] != null && task['ownerUid'] == uid));
          return pending ? const SizedBox.shrink() : _historyTile(context, doc);
        },
      );
    }
    if (spaceId != null && kind == 'ownershipOffered') {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: backend.firestore.doc('spaces/$spaceId').snapshots(),
        builder: (context, snapshot) => snapshot.data?.data()?['pendingOwnerUid'] == uid
            ? const SizedBox.shrink() : _historyTile(context, doc),
      );
    }
    return _historyTile(context, doc);
  }

  Widget _historyTile(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> doc) => ListTile(
                  leading: Icon(
                    doc.data()['readAt'] == null
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                  ),
                  title: Text(doc.data()['title'] as String? ?? 'Activity'),
                  subtitle: Text(
                    [
                      spaceNames[doc.data()['spaceId']] ?? 'Space',
                      doc.data()['body'] as String? ?? '',
                      if (doc.data()['createdAt'] is Timestamp)
                        TimeOfDay.fromDateTime(
                          (doc.data()['createdAt'] as Timestamp)
                              .toDate()
                              .toLocal(),
                        ).format(context),
                    ].where((text) => text.isNotEmpty).join(' · '),
                  ),
                  onTap: () async {
                    if (doc.data()['readAt'] == null) {
                      await doc.reference.update({
                        'readAt': FieldValue.serverTimestamp(),
                      });
                    }
                    final spaceId = doc.data()['spaceId'] as String?;
                    if (spaceId != null && spaceNames.containsKey(spaceId))
                      onOpenSpace?.call(spaceId);
                  },
                );
}
