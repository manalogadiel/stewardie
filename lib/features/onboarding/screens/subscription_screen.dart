import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Optional: purchase loading/failure never blocks finishing onboarding.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    super.key,
    required this.onExplore,
    required this.onContinue,
  });
  final Future<void> Function() onExplore;
  final VoidCallback onContinue;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _explore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onExplore();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Plans could not load. You can continue with Basic.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/branding/stewardie-icon.png',
                  width: 140,
                  height: 140,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'A little more together',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: SoftPop.ink,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Basic is free. Personal Plus is optional.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SoftPop.secondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: SoftPop.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D202633),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'With Personal Plus',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: SoftPop.ink,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Unlimited retained task history\nMore room for spaces and photos',
                    style: TextStyle(color: SoftPop.secondary, height: 1.7),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'One subscription for your account across your spaces.',
                    style: TextStyle(color: SoftPop.secondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SoftPop.secondary),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _loading ? null : _explore,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SoftPop.surface,
                      ),
                    )
                  : const Text('View Plus plans'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onContinue,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    ),
  );
}
