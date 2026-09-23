import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';

class CapturedPhoto {
  const CapturedPhoto(this.bytes, this.source);
  final Uint8List bytes;
  final String source;
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.spaceName});
  final String spaceName;
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  int lens = 0, generation = 0;
  bool busy = false, flash = false, flashAvailable = true, active = true;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    final token = ++generation;
    final previous = controller;
    controller = null;
    if (mounted) setState(() => error = null);
    await previous?.dispose();
    CameraController? next;
    try {
      if (cameras.isEmpty) cameras = await availableCameras();
      if (!mounted || token != generation || !active) return;
      if (cameras.isEmpty) {
        throw const FormatException(
          'No camera is available. You can choose a photo instead.',
        );
      }
      next = CameraController(
        cameras[lens % cameras.length],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted || token != generation || !active) {
        await next.dispose();
        return;
      }
      setState(() {
        controller = next;
        flash = false;
        flashAvailable = true;
      });
    } catch (e) {
      await next?.dispose();
      if (mounted && token == generation) {
        setState(
          () => error = e is CameraException && e.code.contains('Access')
              ? 'Camera access is unavailable. Allow camera access in Settings, or choose a photo.'
              : 'The camera could not start. Try again or choose a photo.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      initialize();
    } else {
      generation++;
      final old = controller;
      controller = null;
      old?.dispose();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  Future<void> capture(bool gallery) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final file = gallery
          ? await ImagePicker().pickImage(
              source: ImageSource.gallery,
              requestFullMetadata: false,
            )
          : await controller!.takePicture();
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) {
          Navigator.pop(
            context,
            CapturedPhoto(bytes, gallery ? 'library' : 'camera'),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'The photo could not be captured. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = controller;
    return Scaffold(
      backgroundColor: const Color(0xFF202633),
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close camera',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          widget.spaceName,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Center(
                    child: camera?.value.isInitialized == true
                        ? CameraPreview(camera!)
                        : error == null
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                TextButton(
                                  onPressed: initialize,
                                  child: const Text(
                                    'Try again',
                                    style: TextStyle(color: SoftPop.sky),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
            if (error != null && camera != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: Align(alignment: Alignment.centerLeft, child:
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(backgroundColor: SoftPop.sky, foregroundColor: SoftPop.ink, minimumSize: const Size(52, 52), shape: const CircleBorder(), elevation: 3, shadowColor: Colors.black26),
                    tooltip: 'Choose photo',
                    onPressed: busy ? null : () => capture(true),
                    icon: const Icon(Icons.photo_library_outlined),
                  ),
                  )),
                  Semantics(
                    label: 'Take photo',
                    button: true,
                    enabled: !busy && camera != null,
                    child: IconButton(
                      tooltip: 'Take photo',
                      padding: EdgeInsets.zero,
                      onPressed: busy || camera == null
                          ? null
                          : () => capture(false),
                      icon: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SoftPop.surface,
                          border: Border.all(color: SoftPop.sky, width: 7),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: busy
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: SoftPop.blue,
                                size: 30,
                              ),
                      ),
                    ),
                  ),
                  Expanded(child: Align(alignment: Alignment.centerRight, child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (cameras.length > 1)
                    IconButton.filledTonal(
                    style: IconButton.styleFrom(backgroundColor: SoftPop.sky, foregroundColor: SoftPop.ink, minimumSize: const Size(52, 52), shape: const CircleBorder(), elevation: 3, shadowColor: Colors.black26),
                      tooltip: 'Switch camera',
                      onPressed: busy
                          ? null
                          : () {
                              lens++;
                              initialize();
                            },
                      icon: const Icon(Icons.flip_camera_ios_outlined),
                    ),
                  if (camera != null && flashAvailable)
                    IconButton.filledTonal(
                    style: IconButton.styleFrom(backgroundColor: SoftPop.sky, foregroundColor: SoftPop.ink, minimumSize: const Size(52, 52), shape: const CircleBorder(), elevation: 3, shadowColor: Colors.black26),
                      tooltip: flash ? 'Turn flash off' : 'Turn flash on',
                      onPressed: busy
                          ? null
                          : () async {
                              try {
                                await camera.setFlashMode(
                                  flash ? FlashMode.off : FlashMode.always,
                                );
                                if (mounted) setState(() => flash = !flash);
                              } catch (_) {
                                if (mounted) {
                                  setState(() => flashAvailable = false);
                                }
                              }
                            },
                      icon: Icon(
                        flash
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                      ),
                    ),
                  ]))),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'A little moment worth keeping.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
