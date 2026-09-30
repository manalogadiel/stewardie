import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as native;

import '../../core/theme.dart';
import '../../core/clay.dart';
import '../../core/soft_pop_backdrop.dart';
import '../../core/device_orientation.dart';
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
    this.pendingPin,
    this.cropRatio,
  });
  final Uint8List bytes;
  final String source;
  final FramingRect framing;
  final PlacePin? pin;
  final String? locationIssue;
  final DateTime? capturedAt;
  final Future<PlacePin?>? pendingPin;
  final String? cropRatio;
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
  bool cameraAccessDenied = false;
  String selectedRatio = 'Original';
  bool attachCaptureLocation = true;
  bool showRatios = false;
  double? physicalTurns;
  StreamSubscription<double>? orientationSubscription;

  DeviceOrientation get captureOrientation {
    if (physicalTurns == null)
      return controller?.value.deviceOrientation ??
          DeviceOrientation.portraitUp;
    return switch ((physicalTurns! * 4).round() % 4) {
      1 => DeviceOrientation.landscapeLeft,
      2 => DeviceOrientation.portraitDown,
      3 => DeviceOrientation.landscapeRight,
      _ => DeviceOrientation.portraitUp,
    };
  }

  String get effectiveRatio {
    final landscape =
        captureOrientation == DeviceOrientation.landscapeLeft ||
        captureOrientation == DeviceOrientation.landscapeRight;
    return switch (selectedRatio) {
      '3:4' || '4:3' => landscape ? '4:3' : '3:4',
      '9:16' || '16:9' => landscape ? '16:9' : '9:16',
      _ => selectedRatio,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    orientationSubscription = physicalControlTurns().listen(
      (turns) {
        if (!mounted) return;
        var next = turns;
        final previous = physicalTurns ?? 0;
        while (next - previous > .5) {
          next -= 1;
        }
        while (next - previous < -.5) {
          next += 1;
        }
        setState(() => physicalTurns = next);
      },
      onError: (Object _) {
        /* Camera orientation remains a fallback. */
      },
    );
    initialize();
  }

  Future<void> initialize() async {
    final token = ++generation;
    final previous = controller;
    controller = null;
    if (mounted) {
      setState(() {
        error = null;
        cameraAccessDenied = false;
      });
    }
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
        setState(() {
          cameraAccessDenied =
              e is CameraException && e.code.contains('Access');
          error = cameraAccessDenied
              ? 'Camera access is unavailable. Allow camera access in Settings, or choose a photo.'
              : 'The camera could not start. Try again or choose a photo.';
        });
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
    orientationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  Future<void> capture(bool gallery) async {
    if (busy) return;
    setState(() => busy = true);
    bool orientationLocked = false;

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
      final shutterRatio = effectiveRatio;
      final shutterOrientation = captureOrientation;
      if (!gallery && controller != null) {
        try {
          final actualOrientation = shutterOrientation;
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
        final selectedCrop = shutterRatio;
        final pendingPin = locationFuture?.then(
          (fix) =>
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
              : null,
        );
        final bytes = await file.readAsBytes();
        const framing = FramingRect.full;
        const PlacePin? pin = null;
        if (mounted) {
          Navigator.pop(
            context,
            CapturedPhoto(
              bytes,
              gallery ? 'library' : 'camera',
              framing: framing,
              cropRatio: gallery ? null : selectedCrop,
              pendingPin: pendingPin,
              pin: pin,
              capturedAt: gallery ? null : shutterAt,
              locationIssue:
                  !gallery &&
                      attachCaptureLocation &&
                      pin == null &&
                      pendingPin == null
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
    Widget rotated(double turns) => AnimatedRotation(
      turns: physicalTurns ?? turns,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      child: child,
    );
    final camera = controller;
    if (camera == null) return rotated(0);
    return ValueListenableBuilder<CameraValue>(
      valueListenable: camera,
      builder: (_, value, _) => rotated(switch (value.deviceOrientation) {
        DeviceOrientation.landscapeLeft => .25,
        DeviceOrientation.landscapeRight => -.25,
        DeviceOrientation.portraitDown => .5,
        DeviceOrientation.portraitUp => 0,
      }),
    );
  }

  Future<void> openCameraSettings() async {
    try {
      final opened = await native.openAppSettings();
      if (!opened && mounted) {
        setState(
          () => error = 'Open device Settings and allow Stewardie to use the camera, or choose a photo.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not open settings. Allow camera access in device Settings, or choose a photo.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = controller;
    return Scaffold(
      backgroundColor: SoftPop.canvas,
      appBar: AppBar(
        foregroundColor: SoftPop.ink,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close camera',
          onPressed: () => Navigator.pop(context),
          icon: orientControl(const Icon(Icons.close_rounded)),
        ),
        title: Text(
          widget.spaceName,
          style: const TextStyle(color: SoftPop.ink, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: SoftPopBackdrop()),
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Center(
                        child: camera?.value.isInitialized == true
                            ? CameraPreview(
                                camera!,
                                child: selectedRatio == 'Original'
                                    ? null
                                    : _FramingGuideOverlay(
                                        ratio: effectiveRatio,
                                      ),
                              )
                            : error == null
                            ? const CircularProgressIndicator(
                                color: SoftPop.ink,
                              )
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  16,
                                  24,
                                  16,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        error!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: SoftPop.ink,
                                        ),
                                      ),
                                      ClayAction(
                                        onPressed: initialize,
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Try again'),
                                      ),
                                      if (cameraAccessDenied)
                                        ClayAction(
                                          onPressed: openCameraSettings,
                                          icon: const Icon(
                                            Icons.settings_rounded,
                                          ),
                                          label: const Text(
                                            'Open camera settings',
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: SoftPop.ink),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        child: showRatios
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final ratio in [
                                        'Original',
                                        '1:1',
                                        '3:4',
                                        '4:3',
                                        '9:16',
                                        '16:9',
                                      ])
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: _ClayCameraButton(
                                            tooltip: 'Use $ratio photo size',
                                            color: selectedRatio == ratio
                                                ? SoftPop.lightButter
                                                : SoftPop.surface,
                                            onPressed: busy
                                                ? null
                                                : () => setState(() {
                                                    selectedRatio = ratio;
                                                    showRatios = false;
                                                  }),
                                            child: orientControl(
                                              Text(
                                                ratio,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: SoftPop.ink,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      _ClayCameraButton(
                        tooltip: 'Photo size',
                        color: SoftPop.surface,
                        onPressed: busy
                            ? null
                            : () => setState(() => showRatios = !showRatios),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            orientControl(
                              const Icon(
                                Icons.aspect_ratio_rounded,
                                color: SoftPop.ink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              effectiveRatio,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: SoftPop.ink,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              showRatios
                                  ? Icons.expand_more_rounded
                                  : Icons.expand_less_rounded,
                              color: SoftPop.ink,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Slots stay anchored; only their contents follow physical rotation.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: _ClayCameraButton(
                            tooltip: 'Choose photo',
                            color: SoftPop.sky,
                            onPressed: busy ? null : () => capture(true),
                            child: orientControl(
                              const Icon(
                                Icons.photo_library_outlined,
                                color: SoftPop.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: _ClayCameraButton(
                            tooltip: attachCaptureLocation
                                ? 'Photo location on'
                                : 'Photo location off',
                            color: attachCaptureLocation
                                ? SoftPop.rose
                                : SoftPop.surface,
                            onPressed: busy
                                ? null
                                : () => setState(
                                    () => attachCaptureLocation =
                                        !attachCaptureLocation,
                                  ),
                            child: orientControl(
                              Icon(
                                attachCaptureLocation
                                    ? Icons.location_on_rounded
                                    : Icons.location_off_rounded,
                                color: SoftPop.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ClayCameraButton(
                        tooltip: 'Take photo',
                        color: SoftPop.surface,
                        size: 72,
                        onPressed: busy || camera == null
                            ? null
                            : () => capture(false),
                        child: busy
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(),
                              )
                            : orientControl(
                                const Icon(
                                  Icons.camera_alt_rounded,
                                  color: SoftPop.ink,
                                  size: 32,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: _ClayCameraButton(
                            tooltip: 'Switch camera',
                            color: SoftPop.sky,
                            onPressed: busy || cameras.length < 2
                                ? null
                                : () {
                                    lens++;
                                    initialize();
                                  },
                            child: orientControl(
                              const Icon(
                                Icons.flip_camera_ios_outlined,
                                color: SoftPop.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: _ClayCameraButton(
                            tooltip: flash ? 'Turn flash off' : 'Turn flash on',
                            color: SoftPop.lightButter,
                            onPressed: busy || camera == null || !flashAvailable
                                ? null
                                : () async {
                                    try {
                                      await camera.setFlashMode(
                                        flash
                                            ? FlashMode.off
                                            : FlashMode.always,
                                      );
                                      if (mounted)
                                        setState(() => flash = !flash);
                                    } catch (_) {
                                      if (mounted) {
                                        setState(() => flashAvailable = false);
                                      }
                                    }
                                  },
                            child: orientControl(
                              Icon(
                                flash
                                    ? Icons.flash_on_rounded
                                    : Icons.flash_off_rounded,
                                color: SoftPop.ink,
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
                    color: SoftPop.ink.withValues(alpha: 0.6),
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

class _ClayCameraButton extends StatelessWidget {
  const _ClayCameraButton({
    required this.tooltip,
    required this.color,
    required this.child,
    this.onPressed,
    this.size = 48,
  });
  final String tooltip;
  final Color color;
  final Widget child;
  final VoidCallback? onPressed;
  final double size;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, .3)!, color],
            ),
            boxShadow: [
              BoxShadow(
                color: SoftPop.ink.withValues(alpha: .14),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(size / 2),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: size, minHeight: size),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Center(widthFactor: 1, heightFactor: 1, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
