import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A compact, semantic loading cue; no GIF and no off-screen animation.
class MomentsLoader extends StatefulWidget {
  const MomentsLoader({super.key, this.sharing = false, this.compact = false});
  final bool sharing, compact;
  @override
  State<MomentsLoader> createState() => _MomentsLoaderState();
}

class _MomentsLoaderState extends State<MomentsLoader>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void synchronize() {
    final animate =
        foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !controller.isAnimating) controller.repeat();
    if (!animate && controller.isAnimating) controller.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    synchronize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    synchronize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: widget.sharing ? 'Sharing moment' : 'Loading moments',
    child: SizedBox(
      height: widget.compact ? 36 : 52,
      child: Align(
        alignment: widget.compact ? Alignment.centerRight : Alignment.center,
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, child) {
              final wave = math.sin(controller.value * math.pi * 2);
              return Transform.translate(
                offset: Offset(
                  0,
                  MediaQuery.disableAnimationsOf(context) ? 0 : wave * 3,
                ),
                child: Transform.rotate(
                  angle: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : wave * .07,
                  child: child,
                ),
              );
            },
            child: Image.asset(
              'assets/illustrations/moments-loader-trio.png',
              width: widget.compact ? 64 : 96,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}
