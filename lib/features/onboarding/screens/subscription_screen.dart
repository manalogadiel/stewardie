import 'package:flutter/material.dart';

import '../../subscription/soft_pop_paywall.dart';

/// The optional paywall is the onboarding page itself, never another sheet.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({
    super.key,
    required this.onExplore,
    required this.onContinue,
  });
  final Future<void> Function() onExplore;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) =>
      SoftPopPaywall(onLoad: onExplore, onContinue: onContinue);
}
