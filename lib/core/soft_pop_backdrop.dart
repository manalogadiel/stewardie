import 'package:flutter/material.dart';

/// Quiet, non-interactive corner art shared by the three main tabs.
class SoftPopBackdrop extends StatelessWidget {
  const SoftPopBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.highContrastOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Opacity(
                opacity: .045,
                child: Image.asset(
                  'assets/illustrations/background-clay-motifs.png',
                  width: 330,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Opacity(
                opacity: .04,
                child: Image.asset(
                  'assets/illustrations/background-soft-waves.png',
                  width: 340,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
