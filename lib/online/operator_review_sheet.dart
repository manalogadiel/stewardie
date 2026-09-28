import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'online_backend.dart';

/// Only the verified founder identity can read these collections in rules.
class OperatorReviewSheet extends StatelessWidget {
  const OperatorReviewSheet({super.key, required this.backend});
  final OnlineBackend backend;

  static Future<void> show(BuildContext context, OnlineBackend backend) =>
      showModalBottomSheet<void>(context: context, isScrollControlled: true,
        builder: (_) => OperatorReviewSheet(backend: backend));

  Future<void> _setStatus(DocumentReference<Map<String, dynamic>> ref, String choice) async {
    await ref.update({
      'status': choice == 'reviewing' ? 'reviewing' : 'closed',
      'reviewedAt': FieldValue.serverTimestamp(),
      if (choice != 'reviewing') 'resolution': choice,
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: FractionallySizedBox(
    heightFactor: .85,
    child: Padding(padding: const EdgeInsets.all(20), child: ListView(children: [
      Text('Private review queue', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Review reports here. Deletion requests are completed only by the private cleanup tool after Firebase and Supabase checks pass.'),
      const SizedBox(height: 20),
      Text('Reports', style: Theme.of(context).textTheme.titleLarge),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: backend.firestore.collection('safetyReports').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Text('Could not load reports.');
          final docs = snap.data?.docs.where((d) => d.data()['status'] != 'closed').toList() ?? [];
          if (docs.isEmpty) return const Text('No open reports.');
          return Column(children: [for (final doc in docs) Card(child: ListTile(
            title: Text('${doc.data()['kind']} · ${doc.data()['reason']}'),
            subtitle: Text('Space ${doc.data()['spaceId']} · Item ${doc.data()['contentId']}\nReporter ${doc.data()['reporterUid']} · Target ${doc.data()['targetUid']}'),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (status) => _setStatus(doc.reference, status),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reviewing', child: Text('Reviewing')),
                PopupMenuItem(value: 'no_action', child: Text('Close · no action needed')),
                PopupMenuItem(value: 'handled_externally', child: Text('Close · action completed')),
              ],
            ),
          ))]);
        },
      ),
      const SizedBox(height: 20),
      Text('Deletion requests', style: Theme.of(context).textTheme.titleLarge),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: backend.firestore.collection('deletionRequests').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Text('Could not load deletion requests.');
          final docs = snap.data?.docs.where((d) => d.data()['status'] != 'complete').toList() ?? [];
          if (docs.isEmpty) return const Text('No pending requests.');
          return Column(children: [for (final doc in docs) Card(child: ListTile(
            title: Text(doc.data()['email'] as String? ?? doc.id),
            subtitle: Text('UID ${doc.id} · ${doc.data()['status']}'),
            trailing: const Icon(Icons.lock_outline_rounded),
          ))]);
        },
      ),
    ])),
  ));
}
