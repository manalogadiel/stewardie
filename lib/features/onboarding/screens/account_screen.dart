import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/stewardie_notices.dart';
import '../../../online/online_backend.dart';
import '../mascot_stage.dart';
import '../staggered_entrance.dart';

/// Screen 3: Add your email
/// Email and password with autofill, visibility toggle, and clear validation.
/// Readable community guidelines and privacy notice before account creation.
/// Create account sends the verification email.
/// Handles errors gracefully without trapping the user in loops.
class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.name,
    required this.initialEmail,
    this.backend,
    required this.onAccountCreated,
    required this.onDraftChanged,
    this.onSubmitForTesting,
  });

  final String name;
  final String initialEmail;
  final OnlineBackend? backend;
  final void Function(User user, bool emailSent) onAccountCreated;
  final void Function(String email) onDraftChanged;
  final Future<void> Function(String email, String password)?
  onSubmitForTesting;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController();

    _emailController.addListener(_notifyDraft);
  }

  void _notifyDraft() {
    widget.onDraftChanged(_emailController.text.trim());
  }

  @override
  void dispose() {
    _passwordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text; // Never trim password!

    User? createdUser;
    bool emailSent = false;

    try {
      if (widget.onSubmitForTesting != null) {
        await widget.onSubmitForTesting!(email, password);
        return;
      }
      if (widget.backend == null) {
        throw StateError('OnlineBackend is required for account creation');
      }
      // 1. Create account
      final credential = await widget.backend!.auth
          .createUserWithEmailAndPassword(email: email, password: password);
      createdUser = credential.user;

      if (createdUser != null) {
        // 2. Set display name
        await createdUser.updateDisplayName(widget.name.trim());

        // 3. Send email verification
        try {
          await createdUser.sendEmailVerification();
          emailSent = true;
        } catch (_) {
          // Email sending failed, but user was created.
          // We will transition to Screen 4 and allow manual resend,
          // rather than deleting or retrying account creation.
          emailSent = false;
        }

        if (mounted) {
          widget.onAccountCreated(createdUser, emailSent);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e.code) {
            'invalid-email' => 'Enter a valid email address.',
            'email-already-in-use' =>
              'This email already has an account. Sign in instead.',
            'weak-password' =>
              'Choose a stronger password (at least 8 characters).',
            'operation-not-allowed' =>
              'Account creation is currently unavailable.',
            'network-request-failed' =>
              'Could not connect. Check your internet.',
            'too-many-requests' =>
              'Too many attempts. Try again in a little while.',
            _ => e.message ?? 'Could not create account. Please try again.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not connect. Please try again.');
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
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MascotStage(pose: MascotPose.skyKey),
                  const SizedBox(height: 16),
                  const StaggeredEntrance(
                    order: 1,
                    child: Text(
                      'Add your email',
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
                  const SizedBox(height: 8),
                  const StaggeredEntrance(
                    order: 2,
                    child: Text(
                      'Your email keeps your spaces connected and secure across devices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: SoftPop.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggeredEntrance(
                    order: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: 'Email address',
                            hintText: 'name@example.com',
                            prefixIcon: const Icon(
                              Icons.mail_outline_rounded,
                              color: SoftPop.secondary,
                            ),
                            filled: true,
                            fillColor: SoftPop.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: SoftPop.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: SoftPop.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: SoftPop.blue,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your email';
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helperText: 'At least 8 characters',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: SoftPop.secondary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: SoftPop.secondary,
                              ),
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: SoftPop.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: SoftPop.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: SoftPop.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: SoftPop.blue,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter a password';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'By continuing, you agree to the Community Guidelines. Read how we use your data in the Privacy Notice.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: SoftPop.secondary,
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => showStewardieNotice(context),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              child: const Text('Privacy Notice'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  showStewardieNotice(context, privacy: false),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              child: const Text('Community Guidelines'),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
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
                                  'Create account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
