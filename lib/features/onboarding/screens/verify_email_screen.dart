import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../mascot_stage.dart';
import '../onboarding_store.dart';
import '../staggered_entrance.dart';

/// Screen 4: Check your email
/// Displays the recipient address, actions to Open email, I've verified,
/// Resend email (with enforced >=30s cooldown and countdown), and Change email.
/// Automatically rechecks verification on app foreground resume.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.user,
    required this.store,
    required this.onVerified,
    this.initialEmailSent = true,
  });

  final User user;
  final OnboardingStore store;
  final VoidCallback onVerified;
  final bool initialEmailSent;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _statusMessage;
  String? _errorMessage;
  int _cooldownSeconds = 0;
  Timer? _countdownTimer;

  late String _currentEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentEmail = widget.user.email ?? '';
    _initCooldown();
    if (!widget.initialEmailSent) {
      _statusMessage = 'We couldn\'t send the initial email automatically. Tap "Resend email" below.';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerificationSilently();
    }
  }

  Future<void> _initCooldown() async {
    final remaining = await widget.store.getRemainingCooldownSeconds(
      widget.user.uid,
    );
    if (!mounted) return;
    if (remaining > 0) {
      setState(() => _cooldownSeconds = remaining);
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        setState(() => _cooldownSeconds = 0);
        timer.cancel();
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _checkVerificationSilently() async {
    try {
      await widget.user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        await refreshed.getIdToken(true);
        if (mounted) widget.onVerified();
      }
    } catch (_) {}
  }

  Future<void> _verifyNow() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
      _errorMessage = null;
    });

    try {
      await widget.user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      await refreshed?.getIdToken(true);

      if (!mounted) return;

      if (refreshed != null && refreshed.emailVerified) {
        widget.onVerified();
      } else {
        setState(() {
          _statusMessage = 'Email verification is still pending. Tap the link in your email, then come back here.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not check verification status. Check connection.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEmailApp() async {
    final mailtoUri = Uri.https('mail.google.com', '/mail/', {
      'authuser': widget.user.email ?? '',
    }).replace(fragment: 'inbox');
    try {
      final launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No default mail app found. Check your email inbox in your browser or mail provider.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open mail app. Check your inbox directly.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_cooldownSeconds > 0 || _busy) return;

    setState(() {
      _busy = true;
      _statusMessage = null;
      _errorMessage = null;
    });

    try {
      await widget.user.sendEmailVerification();
      await widget.store.recordResendTimestamp(widget.user.uid);
      if (mounted) {
        setState(() {
          _statusMessage = 'A fresh verification link is on its way.';
          _cooldownSeconds = 30;
        });
        _startCountdown();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = switch (e.code) {
            'too-many-requests' => 'Too many requests. Please wait a minute.',
            _ => 'Could not resend email right now. Please try again shortly.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not connect. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeEmail() async {
    final controller = TextEditingController(text: _currentEmail);
    final formKey = GlobalKey<FormState>();

    final newEmail = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change email address'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your updated email. We will send the verification link to this new address.',
                style: TextStyle(fontSize: 14, color: SoftPop.secondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'New email',
                  filled: true,
                  fillColor: SoftPop.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (val) {
                  if (val == null || !val.contains('@') || !val.contains('.')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogCtx, controller.text.trim());
              }
            },
            child: const Text('Update & send link'),
          ),
        ],
      ),
    );

    if (newEmail == null || newEmail.isEmpty || newEmail == _currentEmail) {
      return;
    }

    setState(() {
      _busy = true;
      _statusMessage = null;
      _errorMessage = null;
    });

    try {
      // Use verifyBeforeUpdateEmail to update the unverified email safely
      await widget.user.verifyBeforeUpdateEmail(newEmail);
      if (mounted) {
        setState(() {
          _currentEmail = newEmail;
          _statusMessage = 'Verification link sent to $newEmail.';
          _cooldownSeconds = 30;
        });
        _startCountdown();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = switch (e.code) {
            'email-already-in-use' =>
              'This email is already in use by another account.',
            'invalid-email' => 'Please enter a valid email address.',
            'requires-recent-login' =>
              'Please sign in again before changing your email.',
            _ => e.message ?? 'Could not update email. Try again.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not update email.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MascotStage(pose: MascotPose.emailVerification),
              const SizedBox(height: 16),
              const StaggeredEntrance(
                order: 1,
                child: Text(
                  'Check your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: SoftPop.ink,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              StaggeredEntrance(
                order: 2,
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'We sent a verification link to\n',
                        children: [
                          TextSpan(
                            text: _currentEmail,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: SoftPop.ink,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: SoftPop.secondary,
                      ),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F5FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD6E4F0)),
                        ),
                        child: Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SoftPop.ink,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              StaggeredEntrance(
                order: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _verifyNow,
                      style: FilledButton.styleFrom(
                        backgroundColor: SoftPop.blue,
                        foregroundColor: SoftPop.surface,
                        minimumSize: const Size(48, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: SoftPop.surface,
                              ),
                            )
                          : const Text(
                              'I\'ve verified',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _openEmailApp,
                      icon: const Icon(Icons.mail_outline_rounded, size: 20),
                      label: const Text('Open email app'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: SoftPop.border),
                        backgroundColor: SoftPop.surface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: (_cooldownSeconds > 0 || _busy)
                                ? null
                                : _resendEmail,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            child: Text(
                              _cooldownSeconds > 0
                                  ? 'Resend (${_cooldownSeconds}s)'
                                  : 'Resend email',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: _busy ? null : _changeEmail,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Text(
                              'Change email',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
