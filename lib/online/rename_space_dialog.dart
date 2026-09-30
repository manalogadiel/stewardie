import 'package:flutter/material.dart';

Future<String?> showRenameSpaceDialog(BuildContext context, String name) =>
    showDialog<String>(
      context: context,
      builder: (_) => _RenameSpaceDialog(name: name),
    );

class _RenameSpaceDialog extends StatefulWidget {
  const _RenameSpaceDialog({required this.name});
  final String name;
  @override
  State<_RenameSpaceDialog> createState() => _RenameSpaceDialogState();
}

class _RenameSpaceDialogState extends State<_RenameSpaceDialog> {
  late final controller = TextEditingController(text: widget.name);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename space'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
        validator: (value) =>
            (value?.trim().isEmpty ?? true) ? 'Enter a space name.' : null,
        decoration: const InputDecoration(labelText: 'Space name'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate())
            Navigator.pop(context, controller.text.trim());
        },
        child: const Text('Save'),
      ),
    ],
  );
}
