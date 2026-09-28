import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'online_backend.dart';

/// Reporting is private to the operator; blocking only prevents new direct
/// requests and never rewrites shared coordination records.
class SafetySheet {
  static Future<void> report(BuildContext context, OnlineBackend backend, {
    required String spaceId,
    required String kind,
    required String contentId,
    required String targetUid,
  }) async {
    var reason = 'harassment';
    var hide = kind == 'moment';
    final submitted = await showDialog<bool>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: Text(kind == 'member' ? 'Report member' : 'Report shared content'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: const [
              DropdownMenuItem(value: 'harassment', child: Text('Harassment')),
              DropdownMenuItem(value: 'unsafe', child: Text('Unsafe content')),
              DropdownMenuItem(value: 'spam', child: Text('Spam')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => update(() => reason = v ?? reason),
          ),
          if (kind == 'moment') CheckboxListTile(
            value: hide, title: const Text('Hide this moment for me'),
            onChanged: (v) => update(() => hide = v ?? false),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send report')),
        ],
      )),
    );
    if (submitted != true) return;
    try {
      final uid = backend.auth.currentUser!.uid;
      final batch = backend.firestore.batch();
      batch.set(backend.firestore.collection('safetyReports').doc(), {
        'reporterUid': uid, 'spaceId': spaceId, 'kind': kind,
        'contentId': contentId, 'targetUid': targetUid, 'reason': reason,
        'status': 'open', 'createdAt': FieldValue.serverTimestamp(),
      });
      if (hide) {
        batch.set(backend.firestore.doc('accounts/$uid/hidden/${spaceId}_${kind}_$contentId'), {
          'spaceId': spaceId, 'kind': kind, 'contentId': contentId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent for private review.')),
      );
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send report. Try again online.')),
      );
    }
  }

  static Future<void> member(BuildContext context, OnlineBackend backend, {
    required String spaceId, required String memberUid, required String memberName,
  }) async {
    final uid = backend.auth.currentUser!.uid;
    if (uid == memberUid) return;
    final blockRef = backend.firestore.doc('accounts/$uid/blocks/$memberUid');
    final blocked = (await blockRef.get()).exists;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(context: context, builder: (sheet) => SafeArea(
      child: Padding(padding: const EdgeInsets.all(20), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(memberName, style: Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Blocking prevents new direct task requests from this member. Existing shared tasks remain available.'),
          const SizedBox(height: 12),
          TextButton.icon(onPressed: () async {
            Navigator.pop(sheet);
            await report(context, backend, spaceId: spaceId, kind: 'member',
              contentId: memberUid, targetUid: memberUid);
          }, icon: const Icon(Icons.flag_outlined), label: const Text('Report member')),
          TextButton.icon(onPressed: () async {
            try {
              if (blocked) {
                await blockRef.delete();
              } else {
                await blockRef.set({'blockedUid': memberUid, 'createdAt': FieldValue.serverTimestamp()});
              }
              if (sheet.mounted) Navigator.pop(sheet);
            } catch (_) {
              if (sheet.mounted) ScaffoldMessenger.of(sheet).showSnackBar(
                const SnackBar(content: Text('Could not update block. Try again online.')),
              );
            }
          }, icon: Icon(blocked ? Icons.person_add_alt : Icons.block),
            label: Text(blocked ? 'Unblock' : 'Block direct requests')),
        ],
      )),
    ));
  }
}
