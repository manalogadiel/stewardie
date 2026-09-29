import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';

import '../../../core/theme.dart';
import '../../../online/online_backend.dart';
import '../../../online/remembered_account.dart';
import '../mascot_stage.dart';

/// Clean sign-in screen for returning users, preserving remember-account and password reset.
class OnboardingSignInScreen extends StatefulWidget {
  const OnboardingSignInScreen({
    super.key,
    required this.backend,
    required this.database,
    required this.onSignedIn,
    required this.onBackToWelcome,
  });

  final OnlineBackend backend;
  final Database? database;
  final ValueChanged<User> onSignedIn;
  final VoidCallback onBackToWelcome;

  @override
  State<OnboardingSignInScreen> createState() => _OnboardingSignInScreenState();
}

class _OnboardingSignInScreenState extends State<OnboardingSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  RememberedAccount? _remembered;
  bool _remember = false;
  bool _obscurePassword = true;
  bool _resetMode = false;
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    RememberedAccount.load(widget.database).then((account) {
      if (mounted && account != null) {
        setState(() {
          _remembered = account;
          _remember = true;
          _emailController.text = account.email;
        });
      }
    });
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
      _message = null;
    });

    try {
      final email = _emailController.text.trim();

      if (_resetMode) {
        await widget.backend.sendPasswordReset(email);
        if (mounted) {
          setState(() {
            _message =
                'If this email has an account, a password reset link was sent.';
          });
        }
      } else {
        final password = _passwordController.text;
        if (_remember) {
          await RememberedAccount(
            email,
            _remembered?.email == email ? _remembered?.name ?? '' : '',
          ).save(widget.database);
        } else {
          await RememberedAccount.forget(widget.database);
        }

        await widget.backend.signIn(email, password);
        TextInput.finishAutofillContext();

        final user = widget.backend.auth.currentUser;
        if (user != null && mounted) {
          widget.onSignedIn(user);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e.code) {
            'invalid-email' => 'Enter a valid email address.',
            'invalid-credential' ||
            'wrong-password' ||
            'user-not-found' => 'Check your email and password.',
            'too-many-requests' => 'Too many attempts. Try again in a little while.',
            'network-request-failed' => 'Could not connect. Check your internet.',
            _ => e.message ?? 'Could not sign in. Try again.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not connect. Try again.');
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
                  Text(
                    _resetMode ? 'Reset password' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: SoftPop.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _resetMode
                        ? 'Enter your email to receive a password reset link.'
                        : 'Sign in to access your spaces and moments.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: SoftPop.secondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_remembered != null && !_resetMode) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_rounded, size: 20),
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _emailController.text = _remembered!.email;
                              });
                              _passwordFocus.requestFocus();
                            },
                      label: Text(
                        'Continue as ${_remembered!.name.isNotEmpty ? _remembered!.name : _remembered!.email}',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction:
                        _resetMode ? TextInputAction.done : TextInputAction.next,
                    onFieldSubmitted: _resetMode && !_busy ? (_) => _submit() : null,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(
                        Icons.mail_outline_rounded,
                        color: SoftPop.secondary,
                      ),
                      filled: true,
                      fillColor: SoftPop.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: SoftPop.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: SoftPop.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: SoftPop.blue,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (val) =>
                        val == null || !val.contains('@')
                            ? 'Enter a valid email'
                            : null,
                  ),
                  if (!_resetMode) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _busy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
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
                          borderSide: const BorderSide(color: SoftPop.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: SoftPop.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: SoftPop.blue,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter your password' : null,
                    ),
                    if (widget.database != null) ...[
                      const SizedBox(height: 6),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _remember,
                        onChanged: _busy
                            ? null
                            : (val) => setState(() => _remember = val ?? false),
                        title: const Text(
                          'Remember this account on this device',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SoftPop.ink,
                          ),
                        ),
                      ),
                    ],
                  ],
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
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: SoftPop.ink,
                        ),
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
                        : Text(
                            _resetMode ? 'Send reset link' : 'Sign in',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  if (!_resetMode) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _resetMode = true;
                                _error = null;
                                _message = null;
                              });
                            },
                      child: const Text('Forgot password?'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            if (_resetMode) {
                              setState(() {
                                _resetMode = false;
                                _error = null;
                                _message = null;
                              });
                            } else {
                              widget.onBackToWelcome();
                            }
                          },
                    child: Text(
                      _resetMode
                          ? 'Back to sign in'
                          : 'Back to Get started',
                      style: const TextStyle(color: SoftPop.secondary),
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
