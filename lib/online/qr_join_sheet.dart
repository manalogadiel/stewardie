import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/invite_links.dart';
import 'online_backend.dart';

/// Modal bottom sheet with tabs to join a space by typing code or scanning QR.
class QrJoinSheet extends StatefulWidget {
  const QrJoinSheet({
    super.key,
    required this.backend,
    required this.onJoined,
  });

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
      builder: (_) => QrJoinSheet(
        backend: backend,
        onJoined: onJoined,
      ),
    );
  }

  @override
  State<QrJoinSheet> createState() => _QrJoinSheetState();
}

class _QrJoinSheetState extends State<QrJoinSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  CameraController? _cameraController;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _cameraController == null) {
        _initCamera();
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _joinWithToken(String rawToken) async {
    final clean = InviteLinks.sanitize(rawToken);
    if (clean.isEmpty) {
      setState(() => _error = 'Enter a valid 6-letter code');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final inviteSnap = await widget.backend.firestore.collection('invites').doc(clean).get();
      final spaceId = inviteSnap.data()?['spaceId'] as String?;
      if (spaceId != null) {
        final spaceDoc = await widget.backend.firestore.collection('spaces').doc(spaceId).get();
        final requireApproval = spaceDoc.data()?['requireApproval'] == true;
        if (requireApproval) {
          await widget.backend.requestJoinSpace(spaceId);
          if (mounted) {
            setState(() => _busy = false);
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Request Sent'),
                content: const Text(
                  'This space requires approval. The space owner will review your request.',
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
      }

      final res = await widget.backend.call('joinSpace', {'token': clean});
      final resSpaceId = res['spaceId'] as String;
      if (mounted) {
        widget.onJoined(resSpaceId);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not join: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4D0C8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                            borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
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
                            onPressed: () => _joinWithToken(_codeController.text),
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
                  // Tab 2: Camera Scanner View
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _cameraController != null && _cameraController!.value.isInitialized
                        ? CameraPreview(_cameraController!)
                        : Container(
                            color: const Color(0xFF202633),
                            child: const Center(
                              child: Text(
                                'Align QR code in frame',
                                style: TextStyle(
                                  fontFamily: 'NunitoSans',
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
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
    );
  }
}
