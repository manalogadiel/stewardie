import 'package:flutter/material.dart';

/// Keeps the confirmation reachable on small screens with the keyboard open.
class AccountDeletionDialog extends StatefulWidget {
  const AccountDeletionDialog({super.key});

  @override
  State<AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<AccountDeletionDialog> {
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Request account deletion'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type DELETE to request deletion of your account and shared media. Cleanup is reviewed. Sign-in may be disabled during processing.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmation,
          autofocus: true,
          maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            labelText: 'Confirmation',
            hintText: 'DELETE',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _confirmation.text.trim() == 'DELETE'
            ? () => Navigator.of(context).pop(true)
            : null,
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFD32F2F)),
        child: const Text('Request deletion'),
      ),
    ],
  );
}
