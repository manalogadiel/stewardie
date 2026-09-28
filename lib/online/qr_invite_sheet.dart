import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'online_backend.dart';

/// Modal bottom sheet displaying a scannable space invitation.
class QrInviteSheet extends StatefulWidget {
  const QrInviteSheet({
    super.key,
    required this.backend,
    required this.spaceId,
    required this.spaceName,
    required this.inviteToken,
    required this.onRegenerated,
  });

  final OnlineBackend backend;
  final String spaceId;
  final String spaceName;
  final String inviteToken;
  final ValueChanged<String> onRegenerated;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required String spaceId,
    required String spaceName,
    required String inviteToken,
    required ValueChanged<String> onRegenerated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => QrInviteSheet(
        backend: backend,
        spaceId: spaceId,
        spaceName: spaceName,
        inviteToken: inviteToken,
        onRegenerated: onRegenerated,
      ),
    );
  }

  @override
  State<QrInviteSheet> createState() => _QrInviteSheetState();
}

class _QrInviteSheetState extends State<QrInviteSheet> {
  late String _currentToken;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currentToken = widget.inviteToken;
  }

  Future<void> _regenerateToken() async {
    setState(() => _busy = true);
    try {
      final res = await widget.backend.call('createInvite', {
        'spaceId': widget.spaceId,
        'forceNew': true,
      });
      final newToken = res['token'] as String;
      setState(() {
        _currentToken = newToken;
        _busy = false;
      });
      widget.onRegenerated(newToken);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh code: $e')),
        );
      }
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
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
                Text(
                  widget.spaceName,
                  style: const TextStyle(
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
            const SizedBox(height: 4),
            const Text(
              'Scan in Stewardie or enter the code',
              style: TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 14,
                color: Color(0xFF596171),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: _currentToken,
                  version: QrVersions.auto,
                  backgroundColor: const Color(0xFFFFFEFB),
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF202633)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF202633)),
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFEFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E2DA)),
                ),
                child: Text(
                  _currentToken.length == 10
                      ? '${_currentToken.substring(0, 5)} ${_currentToken.substring(5)}'
                      : _currentToken,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Color(0xFF202633),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                    onPressed: () => _copy(_currentToken, 'Invite code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF202633),
                      side: const BorderSide(color: Color(0xFFE5E2DA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Copy code',
                      style: TextStyle(fontFamily: 'NunitoSans', fontWeight: FontWeight.w700),
                    ),
                  ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _regenerateToken,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF596171),
                ),
                child: const Text(
                  'Refresh code',
                  style: TextStyle(fontFamily: 'NunitoSans', fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
