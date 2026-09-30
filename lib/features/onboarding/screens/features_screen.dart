import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../mascot_stage.dart';

class FeatureItem {
  const FeatureItem({
    required this.title,
    required this.body,
    required this.pose,
  });

  final String title;
  final String body;
  final MascotPose pose;
}

/// Screen 6: A little less to juggle
/// Three swipeable feature cards with page indicator dots, Next, then Let's go.
/// Swiping does not change main onboarding progress.
/// Tapping "Let's go" transitions to Screen 7 (All set).
class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({
    super.key,
    required this.initialPage,
    required this.onPageChanged,
    required this.onLetsGo,
  });

  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onLetsGo;

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen> {
  late final PageController _pageController;
  late int _currentPage;

  static const List<FeatureItem> _features = [
    FeatureItem(
      title: 'Share the everyday',
      body: 'See what needs help, who\'s covering it, and what\'s done.',
      pose: MascotPose.shareEveryday,
    ),
    FeatureItem(
      title: 'Keep the little moments',
      body: 'Share photos and celebrate things you finish together.',
      pose: MascotPose.keepMoments,
    ),
    FeatureItem(
      title: 'Stay in the loop',
      body: 'Check moods and plans in each of your spaces.',
      pose: MascotPose.stayInLoop,
    ),
  ];

  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, _features.length - 1);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_isTransitioning) return;
    if (_currentPage < _features.length - 1) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      if (reduceMotion) {
        _pageController.jumpToPage(_currentPage + 1);
      } else {
        _isTransitioning = true;
        _pageController
            .nextPage(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            )
            .then((_) {
              if (mounted) _isTransitioning = false;
            });
      }
    } else {
      widget.onLetsGo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _features.length - 1;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'A little less\nto juggle',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: SoftPop.ink,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 350,
                  child: PageView.builder(
                  controller: _pageController,
                  itemCount: _features.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    widget.onPageChanged(index);
                  },
                  itemBuilder: (context, index) {
                    final item = _features[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MascotStage(pose: item.pose),
                        const SizedBox(height: 12),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: SoftPop.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            item.body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: SoftPop.secondary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Page indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_features.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? SoftPop.blue : const Color(0xFFD6D6DC),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _nextPage,
                style: FilledButton.styleFrom(
                  backgroundColor: SoftPop.blue,
                  foregroundColor: SoftPop.surface,
                  minimumSize: const Size(48, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isLast ? 'Let\'s go' : 'Next',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
