import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'online_backend.dart';
import '../core/member_avatar.dart';
import '../core/theme.dart';
import 'operator_review_sheet.dart';
import 'space_map_sheet.dart';

/// Task requests remain visible even if scheduled notifications are unavailable.
class ActivityInboxSheet extends StatelessWidget {
  const ActivityInboxSheet({
    super.key,
    required this.backend,
    required this.spaceNames,
    this.onOpenSpace,
    this.onSelectSpace,
    this.onOpenTask,
    this.onOpenOwnership,
    this.onOpenMoments,
    this.requests = const [],
  });

  final OnlineBackend backend;
  final Map<String, String> spaceNames;
  final Future<void> Function(String spaceId)? onOpenSpace;
  final Future<void> Function(String spaceId)? onSelectSpace;
  final Future<void> Function(String spaceId, String taskId)? onOpenTask;
  final Future<void> Function(String spaceId)? onOpenOwnership;
  final Future<void> Function(String spaceId)? onOpenMoments;
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
    String? selectedSpace;
    final collection = backend.firestore.collection('accounts/$uid/activity');
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: collection
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          final items = (snapshot.data?.docs ?? [])
              .where(
                (doc) =>
                    doc.data()['pushState'] != 'cancelled' &&
                    (doc.data()['accountNotice'] == true ||
                        spaceNames.containsKey(doc.data()['spaceId'])),
              )
              .toList();
          return StatefulBuilder(
            builder: (context, setFilter) {
              final visible = selectedSpace == null
                  ? items
                  : items
                        .where((doc) => doc.data()['spaceId'] == selectedSpace)
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
                  if (selectedSpace != null)
                    TextButton.icon(
                      onPressed: () => setFilter(() => selectedSpace = null),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('All spaces'),
                    ),
                  for (final entry in spaceNames.entries)
                    if (selectedSpace == null)
                      Card(
                        elevation: 2,
                        color: SoftPop.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.notifications_rounded),
                          title: Text(entry.value),
                          subtitle: Text(
                            '${items.where((doc) => doc.data()['spaceId'] == entry.key && doc.data()['readAt'] == null).length} unread notifications',
                          ),
                          onTap: () async {
                            try {
                              await onSelectSpace?.call(entry.key);
                              if (context.mounted) {
                                setFilter(() => selectedSpace = entry.key);
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This space is no longer available.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                  if (selectedSpace == null) ...requests,
                  if (visible.isEmpty &&
                      requests.isEmpty &&
                      !snapshot.hasError &&
                      snapshot.hasData)
                    const ListTile(title: Text('Youâ€™re all caught up.')),
                  for (final doc in visible) _historyItem(context, doc, uid),
                ],
              );
            },
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
        (kind == 'taskAssigned' || kind == 'action' || kind == 'helpOffered') &&
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
          doc.data()['accountNotice'] == true
              ? 'Account'
              : spaceNames[doc.data()['spaceId']] ?? 'Space',
          doc.data()['body'] as String? ?? '',
          if (doc.data()['createdAt'] is Timestamp)
            '${MaterialLocalizations.of(context).formatMediumDate((doc.data()['createdAt'] as Timestamp).toDate().toLocal())} '
                '${TimeOfDay.fromDateTime((doc.data()['createdAt'] as Timestamp).toDate().toLocal()).format(context)}',
        ].where((text) => text.isNotEmpty).join(' Â· '),
      ),
      onTap: () async {
        if ((doc.data()['reportId'] is String ||
                doc.data()['deletionReview'] == true) &&
            backend.auth.currentUser?.email == 'gadielmanalo19@gmail.com' &&
            backend.auth.currentUser?.emailVerified == true) {
          await OperatorReviewSheet.show(context, backend);
          if (!context.mounted) return;
        }
        final cleanupId = doc.data()['cleanupSpaceId'];
        if (doc.data()['accountNotice'] == true && cleanupId is String) {
          try {
            await backend.callSpaceAction('drainDeletion', cleanupId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cloud cleanup retry requested.')),
              );
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Could not retry. Automatic retry remains scheduled.',
                  ),
                ),
              );
            }
          }
        }
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
        if (kind == 'locationRequested' && taskId != null) {
          try {
            final request = await backend.call('getLocationRequest', {
              'spaceId': spaceId,
              'requestId': taskId,
            });
            if (!context.mounted) return;
            if (request['active'] != true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This location request has ended.'),
                ),
              );
              return;
            }
            final decision = await showDialog<String>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: const Text('Share your location?'),
                content: Text(
                  'A member of ${spaceNames[spaceId]} asked for your location. You choose the duration and can stop anytime.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, 'declined'),
                    child: const Text('Not now'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialog, 'reviewed'),
                    child: const Text('Choose duration'),
                  ),
                ],
              ),
            );
            if (decision == null) return;
            await backend.call('resolveLocationRequest', {
              'spaceId': spaceId,
              'requestId': taskId,
              'decision': decision,
            });
            if (context.mounted && decision == 'reviewed') {
              await onSelectSpace?.call(spaceId);
              if (context.mounted) {
                await SpaceMapSheet.show(
                  context,
                  backend: backend,
                  spaceId: spaceId,
                );
              }
            }
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }
          return;
        }
        if (taskId != null &&
            [
              'taskAssigned',
              'action',
              'helpRequested',
              'helpOffered',
              'taskDeclined',
              'taskEdited',
              'taskArrival',
              'covered',
              'completed',
              'due',
            ].contains(kind) &&
            onOpenTask != null) {
          await onOpenTask!(spaceId, taskId);
        } else if (['photo', 'reaction'].contains(kind) &&
            onOpenMoments != null) {
          await onOpenMoments!(spaceId);
        } else if (['ownershipOffered', 'joinRequested'].contains(kind) &&
            onOpenOwnership != null) {
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
