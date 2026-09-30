import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme.dart';
import '../../core/place_pin.dart';
import 'media_library.dart' show FramingRect;

class CapturedPhoto {
  const CapturedPhoto(
    this.bytes,
    this.source, {
    this.framing = FramingRect.full,
    this.pin,
    this.locationIssue,
    this.capturedAt,
  });
  final Uint8List bytes;
  final String source;
  final FramingRect framing;
  final PlacePin? pin;
  final String? locationIssue;
  final DateTime? capturedAt;
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
  String selectedRatio = 'Original';
  bool attachCaptureLocation = true;

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
    if (state == AppLifecycleState.inactive && busy) return;
    active = state == AppLifecycleState.resumed;
    if (active) {
      if (controller?.value.isInitialized != true) initialize();
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
    bool orientationLocked = false;
    final viewportIsLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    try {
      Future<Position?>? locationFuture;
      String? locationIssue;
      if (!gallery && attachCaptureLocation) {
        try {
          if (!await Geolocator.isLocationServiceEnabled()) {
            locationIssue =
                'Location services are off. The photo has no location.';
          } else {
            var permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }
            if (permission == LocationPermission.denied ||
                permission == LocationPermission.deniedForever) {
              locationIssue =
                  'Location access is unavailable. The photo has no location.';
            } else {
              // Start the fix after permission UI finishes, near the shutter.
              locationFuture =
                  Geolocator.getCurrentPosition(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.medium,
                      timeLimit: Duration(seconds: 12),
                    ),
                  ).then<Position?>(
                    (value) => value,
                    onError: (Object _) {
                      locationIssue =
                          'Could not obtain a fresh photo location.';
                      return null;
                    },
                  );
            }
          }
        } catch (_) {
          locationIssue =
              'Location access is unavailable. The photo has no location.';
        }
      }
      if (!mounted || !active) return;
      if (!gallery && controller?.value.isInitialized != true) {
        await initialize();
        if (!mounted || controller?.value.isInitialized != true) return;
      }
      final shutterAt = DateTime.now().toUtc();
      if (!gallery && controller != null) {
        try {
          final actualOrientation = controller!.value.deviceOrientation;
          await controller!.lockCaptureOrientation(actualOrientation);
          orientationLocked = true;
        } catch (_) {}
      }
      final file = gallery
          ? await ImagePicker().pickImage(
              source: ImageSource.gallery,
              requestFullMetadata: false,
            )
          : await controller!.takePicture();
      if (file != null) {
        final fix = await locationFuture;
        final pin =
            fix != null &&
                fix.timestamp.toUtc().difference(shutterAt).abs() <
                    const Duration(seconds: 30)
            ? PlacePin(
                lat: fix.latitude,
                lng: fix.longitude,
                label: 'Photo location',
                source: 'capture',
                accuracy: fix.accuracy,
                locatedAt: fix.timestamp,
              )
            : null;
        final bytes = await file.readAsBytes();
        FramingRect framing = FramingRect.full;
        if (!gallery && selectedRatio != 'Original') {
          int imgW = 0;
          int imgH = 0;
          final raw = img.decodeImage(bytes);
          final decoded = raw == null ? null : img.bakeOrientation(raw);
          if (decoded != null) {
            imgW = decoded.width;
            imgH = decoded.height;
          } else if (controller?.value.previewSize != null) {
            final preview = controller!.value.previewSize!;
            final currentOrientation = controller?.value.deviceOrientation;
            final isLandscape =
                currentOrientation == DeviceOrientation.landscapeLeft ||
                currentOrientation == DeviceOrientation.landscapeRight ||
                (currentOrientation == null && viewportIsLandscape);
            imgW = isLandscape ? preview.width.toInt() : preview.height.toInt();
            imgH = isLandscape ? preview.height.toInt() : preview.width.toInt();
          }
          if (imgW > 0 && imgH > 0) {
            final target = switch (selectedRatio) {
              '1:1' => 1.0,
              '3:4' => 3.0 / 4.0,
              '4:3' => 4.0 / 3.0,
              '9:16' => 9.0 / 16.0,
              '16:9' => 16.0 / 9.0,
              _ => 1.0,
            };
            framing = FramingRect.fromAspectRatio(
              targetRatio: target,
              imageWidth: imgW,
              imageHeight: imgH,
              ratioName: selectedRatio,
            );
          }
        }
        if (mounted) {
          Navigator.pop(
            context,
            CapturedPhoto(
              bytes,
              gallery ? 'library' : 'camera',
              framing: framing,
              pin: pin,
              capturedAt: gallery ? null : shutterAt,
              locationIssue: !gallery && attachCaptureLocation && pin == null
                  ? locationIssue ?? 'A fresh photo location was unavailable.'
                  : null,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'The photo could not be captured. Try again.');
      }
    } finally {
      if (orientationLocked && controller != null) {
        try {
          await controller!.unlockCaptureOrientation();
        } catch (_) {}
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Widget orientControl(Widget child) {
    final camera = controller;
    if (camera == null) return child;
    return ValueListenableBuilder<CameraValue>(
      valueListenable: camera,
      child: child,
      builder: (context, value, child) {
        final landscapeShell =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final turns = landscapeShell
            ? 0.0
            : switch (value.deviceOrientation) {
                DeviceOrientation.landscapeLeft => .25,
                DeviceOrientation.landscapeRight => -.25,
                DeviceOrientation.portraitDown => .5,
                DeviceOrientation.portraitUp => 0.0,
              };
        return AnimatedRotation(
          turns: turns,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: child,
        );
      },
    );
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
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Center(
                    child: camera?.value.isInitialized == true
                        ? CameraPreview(
                            camera!,
                            child: selectedRatio == 'Original'
                                ? null
                                : _FramingGuideOverlay(ratio: selectedRatio),
                          )
                        : error == null
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 126),
                            child: SingleChildScrollView(
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
            ),
            if (error != null && camera != null)
              Positioned(
                top: 64,
                left: 12,
                right: 12,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            if (camera?.value.isInitialized == true) ...[
              Positioned(
                top: 8,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: IconButton.filledTonal(
                    tooltip: attachCaptureLocation
                        ? 'Photo location on'
                        : 'Photo location off',
                    isSelected: attachCaptureLocation,
                    onPressed: busy
                        ? null
                        : () => setState(
                            () =>
                                attachCaptureLocation = !attachCaptureLocation,
                          ),
                    icon: orientControl(const Icon(Icons.location_off_rounded)),
                    selectedIcon: orientControl(
                      const Icon(Icons.location_on_rounded),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: SoftPop.surface,
                      foregroundColor: SoftPop.ink,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 118,
                left: 12,
                right: 12,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B26),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final r in [
                            'Original',
                            '1:1',
                            '3:4',
                            '4:3',
                            '9:16',
                            '16:9',
                          ])
                            InkWell(
                              onTap: () => setState(() => selectedRatio = r),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedRatio == r
                                      ? SoftPop.surface
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    color: selectedRatio == r
                                        ? SoftPop.ink
                                        : Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // Centered shutter with balanced side controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: SoftPop.sky,
                            foregroundColor: SoftPop.ink,
                            minimumSize: const Size(52, 52),
                            shape: const CircleBorder(),
                            elevation: 3,
                            shadowColor: Colors.black26,
                          ),
                          tooltip: 'Choose photo',
                          onPressed: busy ? null : () => capture(true),
                          icon: orientControl(
                            const Icon(Icons.photo_library_outlined),
                          ),
                        ),
                      ),
                    ),
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
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (cameras.length > 1)
                              IconButton.filledTonal(
                                style: IconButton.styleFrom(
                                  backgroundColor: SoftPop.sky,
                                  foregroundColor: SoftPop.ink,
                                  minimumSize: const Size(52, 52),
                                  shape: const CircleBorder(),
                                  elevation: 3,
                                  shadowColor: Colors.black26,
                                ),
                                tooltip: 'Switch camera',
                                onPressed: busy
                                    ? null
                                    : () {
                                        lens++;
                                        initialize();
                                      },
                                icon: const Icon(
                                  Icons.flip_camera_ios_outlined,
                                ),
                              ),
                            if (cameras.length > 1 &&
                                camera != null &&
                                flashAvailable)
                              const SizedBox(width: 8),
                            if (camera != null && flashAvailable)
                              IconButton.filledTonal(
                                style: IconButton.styleFrom(
                                  backgroundColor: SoftPop.sky,
                                  foregroundColor: SoftPop.ink,
                                  minimumSize: const Size(52, 52),
                                  shape: const CircleBorder(),
                                  elevation: 3,
                                  shadowColor: Colors.black26,
                                ),
                                tooltip: flash
                                    ? 'Turn flash off'
                                    : 'Turn flash on',
                                onPressed: busy
                                    ? null
                                    : () async {
                                        try {
                                          await camera.setFlashMode(
                                            flash
                                                ? FlashMode.off
                                                : FlashMode.always,
                                          );
                                          if (mounted) {
                                            setState(() => flash = !flash);
                                          }
                                        } catch (_) {
                                          if (mounted) {
                                            setState(
                                              () => flashAvailable = false,
                                            );
                                          }
                                        }
                                      },
                                icon: Icon(
                                  flash
                                      ? Icons.flash_on_rounded
                                      : Icons.flash_off_rounded,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FramingGuideOverlay extends StatelessWidget {
  const _FramingGuideOverlay({required this.ratio});
  final String ratio;

  @override
  Widget build(BuildContext context) {
    final target = switch (ratio) {
      '1:1' => 1.0,
      '3:4' => 3.0 / 4.0,
      '4:3' => 4.0 / 3.0,
      '9:16' => 9.0 / 16.0,
      '16:9' => 16.0 / 9.0,
      _ => 1.0,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) return const SizedBox.shrink();

        final current = w / h;
        double frameW = w;
        double frameH = h;
        if (current > target) {
          frameW = h * target;
        } else {
          frameH = w / target;
        }

        return Stack(
          children: [
            Center(
              child: Container(
                width: frameW,
                height: frameH,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
