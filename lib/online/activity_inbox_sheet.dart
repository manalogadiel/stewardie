import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'online_backend.dart';

/// Task requests remain visible even if scheduled notifications are unavailable.
class ActivityInboxSheet extends StatelessWidget {
  const ActivityInboxSheet({
    super.key,
    required this.backend,
    required this.spaceId,
    this.requests = const [],
  });

  final OnlineBackend backend;
  final String spaceId;
  final List<Widget> requests;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required String spaceId,
    List<Widget> requests = const [],
  }) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ActivityInboxSheet(
      backend: backend,
      spaceId: spaceId,
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
            .where('spaceId', isEqualTo: spaceId)
            .orderBy('createdAt', descending: true)
            .limit(60)
            .snapshots(),
        builder: (context, snapshot) {
          final items = (snapshot.data?.docs ?? [])
              .where(
                (doc) =>
                    doc.data()['pushState'] != 'cancelled',
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('Inbox', style: Theme.of(context).textTheme.titleLarge),
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
              for (final doc in items)
                ListTile(
                  leading: Icon(
                    doc.data()['readAt'] == null
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                  ),
                  title: Text(doc.data()['title'] as String? ?? 'Activity'),
                  subtitle: Text(doc.data()['body'] as String? ?? ''),
                  onTap: doc.data()['readAt'] == null
                      ? () => doc.reference.update({
                          'readAt': FieldValue.serverTimestamp(),
                        })
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}
