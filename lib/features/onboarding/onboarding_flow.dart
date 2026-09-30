import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import '../../online/login_scene.dart';
import '../../online/online_backend.dart';
import '../../core/profile_photo.dart';
import 'mascot_stage.dart';
import 'onboarding_progress.dart';
import 'onboarding_store.dart';
import 'permission_adapter.dart';
import 'screens/account_screen.dart';
import 'screens/all_set_screen.dart';
import 'screens/features_screen.dart';
import 'screens/name_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/welcome_screen.dart';
import 'tutorial/tutorial_coordinator.dart';

/// The primary coordinator and presentation shell for the 7-screen onboarding experience.
///
/// Features:
/// - 7-screen state machine with six completed progress increments.
/// - Fluid horizontal slide and fade transitions with directional awareness.
/// - Immediate reduced-motion compliance (short fades, no transforms).
/// - Draft persistence without saving passwords.
/// - Direct sign-in mode for returning users.
/// - Seamless recovery if account creation succeeded but email delivery failed.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.backend,
    this.database,
    required this.onCompleted,
    this.initialStep,
    this.initialUser,
    this.permissionAdapter = const PermissionAdapter(),
  });

  final OnlineBackend backend;
  final Database? database;
  final VoidCallback onCompleted;
  final OnboardingStep? initialStep;
  final User? initialUser;
  final PermissionAdapter permissionAdapter;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final OnboardingStore _store;

  late OnboardingStep _step;
  bool _isSignInMode = false;
  bool _navigatingForward = true;

  User? _currentUser;
  String _nameDraft = '';
  String _emailDraft = '';
  String? _avatarDraft;
  Set<PermissionCapability> _skippedPermissions = {};
  int _featurePageIndex = 0;
  bool _initialEmailSent = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _store = OnboardingStore(widget.database);
    _currentUser = widget.initialUser ?? widget.backend.auth.currentUser;
    _step = widget.initialStep ?? OnboardingStep.welcome;
    _loadState();
  }

  Future<void> _loadState() async {
    final uid = _currentUser?.uid;
    final draft = await _store.loadDraft(uid);

    if (mounted) {
      setState(() {
        if (draft != null) {
          _nameDraft =
              draft['name'] as String? ?? _currentUser?.displayName ?? '';
          _emailDraft = draft['email'] as String? ?? _currentUser?.email ?? '';
          _avatarDraft = draft['avatarBase64'] as String?;
          final preferences = draft['permissions'] as Map<String, dynamic>? ?? {};
          _skippedPermissions = PermissionCapability.values.where((cap) => preferences[cap.name] == 'skipped').toSet();
          _featurePageIndex = draft['featurePageIndex'] as int? ?? 0;

          // Reconcile saved step with authenticated state
          if (_currentUser != null) {
            if (!_currentUser!.emailVerified) {
              _step = OnboardingStep.verifyEmail;
            } else {
              final savedStepIndex = draft['stepIndex'] as int? ?? 4;
              _step = OnboardingStep.fromIndex(
                savedStepIndex < 4 ? 4 : savedStepIndex,
              );
            }
          }
        } else if (_currentUser != null) {
          _nameDraft = _currentUser?.displayName ?? '';
          _emailDraft = _currentUser?.email ?? '';
          _step = _currentUser!.emailVerified
              ? OnboardingStep.permissions
              : OnboardingStep.verifyEmail;
        }
        _loaded = true;
      });
      _precacheMascots();
    }
  }

  void _precacheMascots() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentPose = _poseForStep(_step);
      precacheImage(AssetImage(currentPose.assetPath), context);

      final nextStep = _nextStepFor(_step);
      if (nextStep != null) {
        final nextPose = _poseForStep(nextStep);
        precacheImage(AssetImage(nextPose.assetPath), context);
      }
    });
  }

  static MascotPose _poseForStep(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.welcome:
        return MascotPose.butterWelcome;
      case OnboardingStep.name:
        return MascotPose.attentive;
      case OnboardingStep.account:
        return MascotPose.skyKey;
      case OnboardingStep.verifyEmail:
        return MascotPose.emailVerification;
      case OnboardingStep.permissions:
        return MascotPose.makeItYours;
      case OnboardingStep.profile:
        return MascotPose.profile;
      case OnboardingStep.features:
        return MascotPose.butterTask;
      case OnboardingStep.allSet:
        return MascotPose.done;
    }
  }

  static OnboardingStep? _nextStepFor(OnboardingStep step) {
    final nextIndex = step.index + 1;
    if (nextIndex < OnboardingStep.values.length) {
      return OnboardingStep.values[nextIndex];
    }
    return null;
  }

  void _goToStep(OnboardingStep targetStep, {bool forward = true}) {
    setState(() {
      _navigatingForward = forward;
      _step = targetStep;
    });

    _precacheMascots();

    _store.saveDraft(
      uid: _currentUser?.uid,
      step: targetStep,
      name: _nameDraft,
      email: _emailDraft,
      avatarBase64: _avatarDraft,
      featurePageIndex: _featurePageIndex,
    );
  }

  void _onBack() {
    if (_isSignInMode) {
      setState(() => _isSignInMode = false);
      return;
    }

    switch (_step) {
      case OnboardingStep.welcome:
        break;
      case OnboardingStep.name:
        _goToStep(OnboardingStep.welcome, forward: false);
        break;
      case OnboardingStep.account:
        _goToStep(OnboardingStep.name, forward: false);
        break;
      case OnboardingStep.verifyEmail:
        // Before verification, allow going back to Account or Name to fix email
        _goToStep(OnboardingStep.account, forward: false);
        break;
      case OnboardingStep.permissions:
        // Once verified, cannot step back into email verification
        break;
      case OnboardingStep.profile:
        _goToStep(OnboardingStep.permissions, forward: false);
        break;
      case OnboardingStep.features:
        _goToStep(OnboardingStep.profile, forward: false);
        break;
      case OnboardingStep.allSet:
        // Cannot back out of payoff
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: LoginBackdrop(
        variant: _step.index % 3,
        child: SafeArea(
          child: Column(
            children: [
              if (!_isSignInMode)
                OnboardingProgressBar(
                  step: _step,
                  onBack: _onBack,
                  canGoBack:
                      _step != OnboardingStep.welcome &&
                      _step != OnboardingStep.permissions &&
                      _step != OnboardingStep.allSet,
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: reduceMotion ? 100 : 340),
                  transitionBuilder: (child, animation) {
                    if (reduceMotion) {
                      return FadeTransition(opacity: animation, child: child);
                    }
                    final isIncoming =
                        (child.key as ValueKey?)?.value == _currentStepKey;
                    // ~18 logical pixels subtle travel distance
                    const beginFrac = 18.0 / 380.0;
                    final offsetBegin = isIncoming
                        ? (_navigatingForward
                              ? const Offset(beginFrac, 0.0)
                              : const Offset(-beginFrac, 0.0))
                        : (_navigatingForward
                              ? const Offset(-beginFrac, 0.0)
                              : const Offset(beginFrac, 0.0));
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: offsetBegin,
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: _buildCurrentScreen(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _currentStepKey =>
      _isSignInMode ? 'signin_screen' : '${_step.name}_screen';

  Widget _buildCurrentScreen() {
    if (_isSignInMode) {
      return KeyedSubtree(
        key: const ValueKey('signin_screen'),
        child: OnboardingSignInScreen(
          backend: widget.backend,
          database: widget.database,
          onSignedIn: (user) {
            setState(() {
              _currentUser = user;
              _isSignInMode = false;
            });
            if (!user.emailVerified) {
              _goToStep(OnboardingStep.verifyEmail);
            } else {
              widget.onCompleted();
            }
          },
          onBackToWelcome: () {
            setState(() => _isSignInMode = false);
          },
        ),
      );
    }

    switch (_step) {
      case OnboardingStep.welcome:
        return KeyedSubtree(
          key: const ValueKey('welcome_screen'),
          child: WelcomeScreen(
            onGetStarted: () => _goToStep(OnboardingStep.name),
            onSignIn: () => setState(() => _isSignInMode = true),
          ),
        );

      case OnboardingStep.name:
        return KeyedSubtree(
          key: const ValueKey('name_screen'),
          child: NameScreen(
            initialName: _nameDraft,
            onContinue: (name) {
              _nameDraft = name;
              _goToStep(OnboardingStep.account);
            },
          ),
        );

      case OnboardingStep.account:
        return KeyedSubtree(
          key: const ValueKey('account_screen'),
          child: AccountScreen(
            name: _nameDraft,
            initialEmail: _emailDraft,
            backend: widget.backend,
            onDraftChanged: (email) {
              _emailDraft = email;
            },
            onAccountCreated: (user, emailSent) {
              setState(() {
                _currentUser = user;
                _initialEmailSent = emailSent;
              });
              _goToStep(OnboardingStep.verifyEmail);
            },
          ),
        );

      case OnboardingStep.verifyEmail:
        return KeyedSubtree(
          key: const ValueKey('verify_screen'),
          child: VerifyEmailScreen(
            user: _currentUser ?? widget.backend.auth.currentUser!,
            store: _store,
            initialEmailSent: _initialEmailSent,
            onVerified: () {
              _goToStep(OnboardingStep.permissions);
            },
          ),
        );

      case OnboardingStep.permissions:
        return KeyedSubtree(
          key: const ValueKey('permissions_screen'),
          child: PermissionsScreen(
            adapter: widget.permissionAdapter,
            initialSkipped: _skippedPermissions,
            onSkippedChanged: (skipped) {
              _skippedPermissions = skipped;
              _store.saveDraft(uid: _currentUser?.uid, step: OnboardingStep.permissions,
                permissions: {for (final cap in skipped) cap.name: 'skipped'});
            },
            onContinue: () {
              _goToStep(OnboardingStep.profile);
            },
          ),
        );

      case OnboardingStep.profile:
        return KeyedSubtree(key: const ValueKey('profile_screen'), child: ProfileScreen(
          name: _nameDraft, initialPhoto: _avatarDraft,
          onPhotoChanged: (photo) {
            _avatarDraft = photo;
            _store.saveDraft(uid: _currentUser?.uid, step: OnboardingStep.profile,
              avatarBase64: photo, clearAvatar: photo == null);
          },
          onContinue: () => _goToStep(OnboardingStep.features),
        ));

      case OnboardingStep.features:
        return KeyedSubtree(
          key: const ValueKey('features_screen'),
          child: FeaturesScreen(
            initialPage: _featurePageIndex,
            onPageChanged: (page) {
              _featurePageIndex = page;
              _store.saveDraft(
                uid: _currentUser?.uid,
                step: OnboardingStep.features,
                featurePageIndex: page,
              );
            },
            onLetsGo: () {
              _goToStep(OnboardingStep.allSet);
            },
          ),
        );

      case OnboardingStep.allSet:
        return KeyedSubtree(
          key: const ValueKey('all_set_screen'),
          child: AllSetScreen(
            name: _nameDraft.isNotEmpty
                ? _nameDraft
                : (_currentUser?.displayName ?? ''),
            onOpenApp: () async {
              final uid =
                  _currentUser?.uid ?? widget.backend.auth.currentUser?.uid;
              if (uid != null) {
                if (_avatarDraft case final avatar?) {
                  try {
                    await ProfilePhoto.save(avatar);
                  } catch (_) {
                    await _store.savePendingAvatar(uid, avatar);
                  }
                }
                await _store.markCompleted(uid, backend: widget.backend);
                TutorialCoordinator.markEligibleForFirstUsePrompt(uid);
              }
              widget.onCompleted();
            },
          ),
        );
    }
  }
}
