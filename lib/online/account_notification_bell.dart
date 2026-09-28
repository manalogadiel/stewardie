import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
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
  State<AccountNotificationBell> createState() => _AccountNotificationBellState();
}

class _AccountNotificationBellState extends State<AccountNotificationBell> {
  final subscriptions = <StreamSubscription<dynamic>>[];
  final requests = <String, Set<String>>{};
  final activity = <String, Set<String>>{};

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
    final ids = widget.spaceIds.toSet().toList()..sort();
    for (final spaceId in ids) {
      subscriptions.add(widget.backend.activeTasks(spaceId).listen((snapshot) {
        final active = <String>{};
        for (final task in snapshot.docs) {
          final data = task.data();
          if ((data['status'] == 'requested' && data['requestedUid'] == widget.uid) ||
              (data['offeredUid'] != null && data['ownerUid'] == widget.uid)) {
            active.add('task:$spaceId:${task.id}');
          }
        }
        if (mounted) setState(() => requests['tasks:$spaceId'] = active);
      }));
      subscriptions.add(widget.backend.firestore.doc('spaces/$spaceId').snapshots().listen((snapshot) {
        if (mounted) {
          setState(() => requests['owner:$spaceId'] =
              snapshot.data()?['pendingOwnerUid'] == widget.uid
                  ? {'ownership:$spaceId'} : <String>{});
        }
      }));
    }
    for (var offset = 0; offset < ids.length; offset += 30) {
      final group = ids.skip(offset).take(30).toList();
      final groupId = '$offset';
      subscriptions.add(widget.backend.firestore
          .collection('accounts/${widget.uid}/activity')
          .where('spaceId', whereIn: group)
          .where('readAt', isNull: true)
          .limit(100)
          .snapshots()
          .listen((snapshot) {
        final unread = <String>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data['pushState'] == 'cancelled') continue;
          final taskId = data['taskId'] as String? ??
              (['taskAssigned', 'helpRequested', 'covered', 'completed']
                  .contains(data['kind']) ? data['entityId'] as String? : null);
          final kind = data['kind'] as String?;
          final spaceId = data['spaceId'] as String?;
          if (spaceId == null) continue;
          unread.add(taskId != null && (kind == 'action' || kind == 'taskAssigned')
              ? 'task:$spaceId:$taskId'
              : kind == 'ownershipOffered'
                  ? 'ownership:$spaceId'
                  : 'activity:${doc.id}');
        }
        if (mounted) setState(() => activity[groupId] = unread);
      }));
    }
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
    final unread = <String>{
      for (final set in requests.values) ...set,
      for (final set in activity.values) ...set,
    }.length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_rounded),
        if (unread > 0)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: const BoxDecoration(color: SoftPop.blue, shape: BoxShape.circle),
              child: Center(
                child: Text(unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }
}
