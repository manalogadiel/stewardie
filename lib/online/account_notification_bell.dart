import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'notification_identity.dart';
import 'online_backend.dart';

/// Combines the account inbox with live requests, which cannot wait for cron.
class AccountNotificationBell extends StatefulWidget {
  const AccountNotificationBell({
    super.key,
    required this.backend,
    required this.uid,
    required this.spaceIds,
  });

  final OnlineBackend backend;
  final String uid;
  final List<String> spaceIds;

  @override
  State<AccountNotificationBell> createState() =>
      _AccountNotificationBellState();
}

class _AccountNotificationBellState extends State<AccountNotificationBell> {
  final subscriptions = <StreamSubscription<dynamic>>[];
  final requests = <String, Set<String>>{};
  final activity = <String, Set<String>>{};
  int? cloudCount;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant AccountNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.spaceIds.join('|') != widget.spaceIds.join('|')) {
      _listen();
    }
  }

  void _listen() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    subscriptions.clear();
    requests.clear();
    activity.clear();
    cloudCount = null;
    if (widget.backend.auth.currentUser?.uid != widget.uid) return;
    if (OnlineBackend.useSupabaseCore && !OnlineBackend.useEmulator) {
      subscriptions.add(
        widget.backend.coreStore
            .watch(
              () => widget.backend.coreData.call('notificationSummary', {}),
            )
            .listen(
              (summary) {
                if (mounted) {
                  setState(
                    () => cloudCount = (summary['total'] as num).toInt(),
                  );
                }
              },
              onError: (Object _) {
                /* Keep the last confirmed badge during a retry. */
              },
            ),
      );
      return;
    }
    final ids = widget.spaceIds.toSet().toList()..sort();
    for (final spaceId in ids) {
      subscriptions.add(
        widget.backend
            .activeTasks(spaceId)
            .listen(
              (snapshot) {
                final active = <String>{};
                for (final task in snapshot.docs) {
                  final key = liveRequestKey(
                    spaceId,
                    task.id,
                    widget.uid,
                    task.data(),
                  );
                  if (key != null) active.add(key);
                }
                if (mounted) {
                  setState(() => requests['tasks:$spaceId'] = active);
                }
              },
              onError: (Object error) {
                if (mounted) setState(() => requests.remove('tasks:$spaceId'));
              },
            ),
      );
      subscriptions.add(
        widget.backend.firestore
            .doc('spaces/$spaceId')
            .snapshots()
            .listen(
              (snapshot) {
                if (mounted) {
                  setState(
                    () => requests['owner:$spaceId'] =
                        snapshot.data()?['pendingOwnerUid'] == widget.uid
                        ? {'ownership:$spaceId'}
                        : <String>{},
                  );
                }
              },
              onError: (Object error) {
                if (mounted) setState(() => requests.remove('owner:$spaceId'));
              },
            ),
      );
    }
    subscriptions.add(
      widget.backend.firestore
          .collection('accounts/${widget.uid}/activity')
          .where('readAt', isNull: true)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .listen(
            (snapshot) {
              final unread = <String>{};
              for (final doc in snapshot.docs) {
                final data = doc.data();
                if (data['accountNotice'] != true &&
                    !ids.contains(data['spaceId'])) {
                  continue;
                }
                final key = unreadActivityKey(doc.id, data);
                if (key != null) unread.add(key);
              }
              if (mounted) setState(() => activity['account'] = unread);
            },
            onError: (Object error) {
              // Keep live requests usable while an index builds or access changes.
              if (mounted) setState(() => activity.remove('account'));
            },
          ),
    );
  }

  @override
  void dispose() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread =
        cloudCount ?? uniqueNotificationCount(requests.values, activity.values);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          unread > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          color: unread > 0 ? SoftPop.blue : SoftPop.secondary,
        ),
        if (unread > 0)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: SoftPop.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
