import 'package:flutter/material.dart';

/// Available transparent mascot illustrations for onboarding and tutorial flow.
enum MascotPose {
  butterWelcome('assets/illustrations/onboarding-butter-welcome.png'),
  attentive('assets/illustrations/onboarding-attentive.png'),
  skyKey('assets/illustrations/onboarding-sky-key.png'),
  emailVerification('assets/illustrations/onboarding-email-verification.png'),
  makeItYours('assets/illustrations/onboarding-make-it-yours.png'),
  butterTask('assets/illustrations/onboarding-butter-task.png'),
  roseCamera('assets/illustrations/onboarding-rose-camera.png'),
  mintCalendar('assets/illustrations/onboarding-mint-calendar.png'),
  done('assets/illustrations/onboarding-done.png'),
  skyFront('assets/illustrations/login-sky-front.png'),
  celebrate('assets/illustrations/celebrate.png');

  const MascotPose(this.assetPath);
  final String assetPath;

  // Backwards-compatible aliases:
  static const MascotPose mintAttentive = attentive;
  static const MascotPose rosePeekaboo = makeItYours;
}

/// A transparent artwork slot that gracefully displays static 3D clay
/// mascot illustrations floating directly on the page background without
/// cards, borders, shadows, or background fills.
///
/// Motion rules:
/// - One-time subtle entrance animation on mount (no persistent bouncing loop)
/// - For [celebrating], a single gentle upward lift
/// - When [MediaQuery.disableAnimationsOf] is true, motion is completely suppressed
/// - Responsive height adapting when virtual keyboard is displayed
/// - ExcludeSemantics so decorative character art does not pollute accessibility tree
/// - No generic icon error fallback: asset paths must be valid and errors visible in development
class MascotStage extends StatefulWidget {
  const MascotStage({
    super.key,
    required this.pose,
    this.compact = false,
    this.celebrating = false,
  });

  final MascotPose pose;
  final bool compact;
  final bool celebrating;

  @override
  State<MascotStage> createState() => _MascotStageState();
}

class _MascotStageState extends State<MascotStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // Subtle one-time entrance: gentle upward lift for celebration, or subtle settle for normal
    final beginOffset = widget.celebrating ? 10.0 : 4.0;
    _slideAnimation = Tween<double>(begin: beginOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_controller.isCompleted && mounted) {
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(covariant MascotStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pose != widget.pose) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Responsive height: shrink when keyboard is active to keep form inputs & buttons onscreen
    final double stageHeight = keyboardOpen
        ? (widget.compact ? 60.0 : 88.0)
        : (widget.compact ? 90.0 : 170.0);

    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        height: stageHeight,
        margin: widget.compact
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        alignment: Alignment.center,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: stageHeight,
            maxWidth: stageHeight * 1.35,
          ),
          // Transparent slot: strictly NO background color, NO border, NO box-shadow, NO clipping
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              if (reduceMotion || keyboardOpen || _controller.isCompleted) {
                return child!;
              }

              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: child,
                ),
              );
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: Image.asset(
                widget.pose.assetPath,
                key: ValueKey(widget.pose.assetPath),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
