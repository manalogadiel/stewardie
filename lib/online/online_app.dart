import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'online_backend.dart';
import 'online_home.dart';

class OnlineApp extends StatefulWidget {
  const OnlineApp({super.key, required this.backend});
  final OnlineBackend backend;

  @override
  State<OnlineApp> createState() => _OnlineAppState();
}

class _OnlineAppState extends State<OnlineApp> {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Stewardie',
    debugShowCheckedModeBanner: false,
    theme: SoftPop.theme,
    home: StreamBuilder<User?>(
      stream: widget.backend.auth.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return OnlineAccountEntry(backend: widget.backend);
        if (!user.emailVerified) {
          return OnlineVerifyEmail(
            backend: widget.backend,
            user: user,
            onRefresh: () => setState(() {}),
          );
        }
        return OnlineHome(backend: widget.backend, user: user);
      },
    ),
  );
}

class OnlineAccountEntry extends StatefulWidget {
  const OnlineAccountEntry({super.key, required this.backend});
  final OnlineBackend backend;

  @override
  State<OnlineAccountEntry> createState() => _OnlineAccountEntryState();
}

class _OnlineAccountEntryState extends State<OnlineAccountEntry> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await widget.backend.register(_name.text, _email.text, _password.text);
      } else {
        await widget.backend.signIn(_email.text, _password.text);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _error = error.message ?? 'Could not sign in.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not connect. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: SoftPop.blue,
                    size: 42,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'A little more together',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _register ? 'Make your account' : 'Welcome back',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (_register) ...[
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Your name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    onFieldSubmitted: (_) => _busy ? null : _submit(),
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) => value == null || value.length < 8
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_register ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _error = null;
                          }),
                    child: Text(
                      _register
                          ? 'I already have an account'
                          : 'Create an account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class OnlineVerifyEmail extends StatefulWidget {
  const OnlineVerifyEmail({
    super.key,
    required this.backend,
    required this.user,
    required this.onRefresh,
  });
  final OnlineBackend backend;
  final User user;
  final VoidCallback onRefresh;

  @override
  State<OnlineVerifyEmail> createState() => _OnlineVerifyEmailState();
}

class _OnlineVerifyEmailState extends State<OnlineVerifyEmail> {
  bool _busy = false;
  String? _message;

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.user.reload();
      await widget.backend.auth.currentUser?.getIdToken(true);
      if (!mounted) return;
      widget.onRefresh();
      if (!(widget.backend.auth.currentUser?.emailVerified ?? false)) {
        setState(() => _message = 'Email verification is still pending.');
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not check yet. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: SoftPop.blue,
                  size: 58,
                ),
                const SizedBox(height: 20),
                Text(
                  'Verify your email',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Use the verification link for ${widget.user.email ?? 'your account'}, then come back here.',
                  textAlign: TextAlign.center,
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _refresh,
                  child: const Text('I verified my email'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          try {
                            await widget.user.sendEmailVerification();
                            if (mounted) {
                              setState(
                                () => _message = 'Another link is ready.',
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => _message = 'Could not resend. Try again.',
                              );
                            }
                          }
                        },
                  child: const Text('Resend link'),
                ),
                TextButton(
                  onPressed: _busy ? null : widget.backend.auth.signOut,
                  child: const Text('Use a different account'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
