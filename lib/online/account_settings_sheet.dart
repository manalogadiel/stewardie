import 'dart:async';

import 'package:flutter/material.dart';

import '../core/member_avatar.dart';
import '../core/sound_feedback.dart';
import 'app_sound_settings.dart';
import '../core/profile_photo.dart';
import 'online_backend.dart';
import 'live_location_service.dart';
import 'push_service.dart';
import 'notification_settings_sheet.dart';
import 'operator_review_sheet.dart';

/// Modal bottom sheet for user profile settings, tier info, sign out, and deletion.
class AccountSettingsSheet extends StatefulWidget {
  const AccountSettingsSheet({
    super.key,
    required this.backend,
    required this.tier,
    required this.spaceId,
    required this.onSignedOut,
    this.onTakeTour,
    this.onAccountDeleted,
  });

  final OnlineBackend backend;
  final String tier;
  final String? spaceId;
  final VoidCallback onSignedOut;
  final VoidCallback? onTakeTour;
  final Future<void> Function()? onAccountDeleted;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required String tier,
    required String? spaceId,
    required VoidCallback onSignedOut,
    VoidCallback? onTakeTour,
    Future<void> Function()? onAccountDeleted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AccountSettingsSheet(
        backend: backend,
        tier: tier,
        spaceId: spaceId,
        onSignedOut: onSignedOut,
        onTakeTour: onTakeTour,
        onAccountDeleted: onAccountDeleted,
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

  Future<void> _changePhoto() async {
    try {
      final photo = await ProfilePhoto.choose(context);
      if (photo == null || !mounted) {
        return;
      }
      setState(() => _busy = true);
      final intent = SoundFeedback.captureIntent();
      await ProfilePhoto.save(photo);
      unawaited(
        SoundFeedback.confirmed(
          SoundCue.saved,
          'avatar/${DateTime.now().microsecondsSinceEpoch}',
          intent,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your photo. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _removePhoto() async {
    final intent = SoundFeedback.captureIntent();
    try {
      setState(() => _busy = true);
      await ProfilePhoto.remove();
      unawaited(
        SoundFeedback.confirmed(
          SoundCue.saved,
          'avatar-remove/${DateTime.now().microsecondsSinceEpoch}',
          intent,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove your photo.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.backend.auth.currentUser?.displayName ?? '',
    );
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) {
        final newName = _nameController.text.trim();
        if (newName.isNotEmpty &&
            newName != widget.backend.auth.currentUser?.displayName) {
          unawaited(
            widget.backend.updateProfileName(newName).catchError((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not save your name. Please retry.'),
                  ),
                );
              }
            }),
          );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in with this account later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    SoundFeedback.clearAccount();
    await LiveLocationService.instance.stopSharing(userInitiated: false);
    await PushService.instance.logOut();
    if (!mounted) return;
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
          title: const Text('Request account deletion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Type DELETE to request permanent account and shared-media deletion. Your request will be reviewed. You can sign in until processing starts; sign-in may be disabled while cleanup runs.',
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
              child: const Text('Send deletion request'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await widget.backend.requestAccountDeletion();
      await widget.onAccountDeleted?.call();
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Deletion request received. You can sign in until processing starts.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete account: $e')));
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
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * .84),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                Row(
                  children: [
                    MemberAvatar(
                      uid: widget.backend.auth.currentUser!.uid,
                      name:
                          widget.backend.auth.currentUser!.displayName ??
                          'Member',
                      radius: 28,
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _busy ? null : _changePhoto,
                      child: const Text('Change photo'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _removePhoto,
                      child: const Text('Remove'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                          isDense: true,
                          constraints: BoxConstraints(minHeight: 48),
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPlus
                              ? const Color(0xFFF8E7B0)
                              : const Color(0xFFF1EFEA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isPlus ? 'PLUS' : 'BASIC',
                          style: TextStyle(
                            fontFamily: 'NunitoSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isPlus
                                ? const Color(0xFF8C6D1F)
                                : const Color(0xFF596171),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const AppSoundSettings(),
                const SizedBox(height: 24),
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  if (widget.spaceId case final spaceId?) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        final route = ModalRoute.of(context);
                        final rootContext = Navigator.of(
                          context,
                          rootNavigator: true,
                        ).context;
                        final backend = widget.backend;
                        Navigator.pop(context);
                        await route?.completed;
                        if (rootContext.mounted) {
                          await NotificationSettingsSheet.show(
                            rootContext,
                            backend,
                            spaceId,
                          );
                        }
                      },
                      icon: const Icon(Icons.notifications_outlined),
                      label: const Text('Reminder settings'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (email.toLowerCase() == 'gadielmanalo19@gmail.com') ...[
                    TextButton.icon(
                      onPressed: () =>
                          OperatorReviewSheet.show(context, widget.backend),
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('Private review queue'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 50),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onTakeTour?.call();
                      },
                      icon: Image.asset(
                        'assets/illustrations/clay-navigation.png',
                        width: 28,
                        height: 28,
                      ),
                      label: const Text(
                        'Take a tour',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF202633),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5E2DA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 50),
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
        ),
      ),
    );
  }
}
