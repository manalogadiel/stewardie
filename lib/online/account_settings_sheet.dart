import 'package:flutter/material.dart';

import 'online_backend.dart';

/// Modal bottom sheet for user profile settings, tier info, sign out, and deletion.
class AccountSettingsSheet extends StatefulWidget {
  const AccountSettingsSheet({
    super.key,
    required this.backend,
    required this.tier,
    required this.onSignedOut,
  });

  final OnlineBackend backend;
  final String tier;
  final VoidCallback onSignedOut;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required String tier,
    required VoidCallback onSignedOut,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AccountSettingsSheet(
        backend: backend,
        tier: tier,
        onSignedOut: onSignedOut,
      ),
    );
  }

  @override
  State<AccountSettingsSheet> createState() => _AccountSettingsSheetState();
}

class _AccountSettingsSheetState extends State<AccountSettingsSheet> {
  late final TextEditingController _nameController;
  final FocusNode _nameFocus = FocusNode();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.backend.auth.currentUser?.displayName ?? '',
    );
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) {
        final newName = _nameController.text.trim();
        if (newName.isNotEmpty) {
          widget.backend.updateProfileName(newName);
        }
      }
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    Navigator.of(context).pop();
    await widget.backend.auth.signOut();
    widget.onSignedOut();
  }

  Future<void> _deleteAccount() async {
    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Delete account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Type DELETE to confirm permanent account deletion. All your data will be permanently removed.',
                style: TextStyle(fontFamily: 'NunitoSans', fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setDlgState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: confirmController.text.trim() == 'DELETE'
                  ? () => Navigator.of(ctx).pop(true)
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD32F2F),
              ),
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await widget.backend.deleteAccount();
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSignedOut();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete account: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final email = widget.backend.auth.currentUser?.email ?? '';
    final isPlus = widget.tier.toLowerCase() == 'plus';

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4D0C8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Account',
                  style: TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202633),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF596171)),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFEFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E2DA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Display name',
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 12,
                      color: Color(0xFF8E95A5),
                    ),
                  ),
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    style: const TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202633),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFEFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E2DA)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 12,
                          color: Color(0xFF8E95A5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF202633),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPlus ? const Color(0xFFF8E7B0) : const Color(0xFFE8EEFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPlus ? 'PLUS' : 'BASIC',
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isPlus ? const Color(0xFF8C6D1F) : const Color(0xFF244BFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else ...[
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF202633),
                    side: const BorderSide(color: Color(0xFFE5E2DA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Sign out',
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _deleteAccount,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F),
                  ),
                  child: const Text(
                    'Delete account',
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
