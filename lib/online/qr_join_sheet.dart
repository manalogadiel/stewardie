import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/invite_links.dart';
import 'online_backend.dart';

/// Modal bottom sheet with tabs to join a space by typing code or scanning QR.
class QrJoinSheet extends StatefulWidget {
  const QrJoinSheet({super.key, required this.backend, required this.onJoined});

  final OnlineBackend backend;
  final ValueChanged<String> onJoined;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required ValueChanged<String> onJoined,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => QrJoinSheet(backend: backend, onJoined: onJoined),
    );
  }

  @override
  State<QrJoinSheet> createState() => _QrJoinSheetState();
}

class _QrJoinSheetState extends State<QrJoinSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final barcode in capture.barcodes) {
      final token = InviteLinks.codeFromScan(barcode.rawValue ?? '');
      if (token != null) {
        _joinWithToken(token);
        return;
      }
    }
  }

  Future<void> _joinWithToken(String rawToken) async {
    if (_busy) return;
    final clean = InviteLinks.sanitize(rawToken);
    if (!InviteLinks.isValidCode(clean)) {
      setState(() => _error = 'Enter a valid invite code');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (!await widget.backend.canAddSpace()) {
        throw StateError(
          'Basic includes 3 spaces. Leave a space before joining another.',
        );
      }
      final invite = await widget.backend.call('previewInvite', {
        'token': clean,
      });
      final spaceId = invite['spaceId'] as String;
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Join space?'),
          content: Text(
            'You were invited to join ${invite['spaceName'] ?? 'this space'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (invite['requireApproval'] == true) {
        final approvedRequest = await widget.backend.requestJoinSpace(
          spaceId,
          clean,
        );
        if (!approvedRequest && mounted) {
          setState(() => _busy = false);
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Request Sent'),
              content: const Text(
                'The owner will review your request. Enter this code again after approval to join.',
                style: TextStyle(fontFamily: 'NunitoSans'),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
      }

      final res = await widget.backend.call('redeemInvite', {'token': clean});
      final resSpaceId = res['spaceId'] as String;
      if (mounted) {
        Navigator.of(context).pop();
        widget.onJoined(resSpaceId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is StateError ? e.message : 'Could not join. Check your connection or ask the owner for a new code.';
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Join space',
                  style: TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202633),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF596171)),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF244BFF),
              labelColor: const Color(0xFF244BFF),
              unselectedLabelColor: const Color(0xFF596171),
              labelStyle: const TextStyle(
                fontFamily: 'NunitoSans',
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              tabs: const [
                Tab(text: 'Enter code'),
                Tab(text: 'Scan QR'),
              ],
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  color: Color(0xFFD32F2F),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 240,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Code Input
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _codeController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          color: Color(0xFF202633),
                        ),
                        decoration: InputDecoration(
                          hintText: 'CODE',
                          hintStyle: const TextStyle(
                            color: Color(0xFF8E95A5),
                            letterSpacing: 4,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFFEFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E2DA),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E2DA),
                            ),
                          ),
                        ),
                        onSubmitted: (val) => _joinWithToken(val),
                      ),
                      const SizedBox(height: 24),
                      if (_busy)
                        const CircularProgressIndicator()
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: () =>
                                _joinWithToken(_codeController.text),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF244BFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Join space',
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Tab 2: scan only while this tab is visible.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_tabController.index == 1)
                          MobileScanner(
                            onDetect: _onDetect,
                            errorBuilder: (context, error) => Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'Camera unavailable. Enter the code instead.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(color: const Color(0xFF202633)),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Center the QR code in view, or type the code in the "Enter code" tab',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
