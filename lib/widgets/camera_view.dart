import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Fills its box with the live camera picture (cropping the edges, like a
/// photo set to "cover"). The app is held upright, so the camera's
/// landscape-shaped preview is turned on its side to fit.
class CameraFill extends StatelessWidget {
  final CameraController? controller;
  final String? error;
  const CameraFill({super.key, required this.controller, this.error});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final size = c?.value.previewSize;
    if (c == null || !c.value.isInitialized || size == null) {
      return Container(
        color: DT.viewfinder,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: error == null
            ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
            : Text(error!, textAlign: TextAlign.center, style: Fonts.sans(13, Colors.white70, height: 1.4)),
      );
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        // The raw camera picture, without CameraPreview's automatic turning.
        // CameraPreview turns the picture when recording is locked to
        // landscape, expecting the whole app to turn too; Dear Today stays
        // upright, so that turn would squeeze the picture mid-recording.
        child: SizedBox(width: size.height, height: size.width, child: c.buildPreview()),
      ),
    );
  }
}

/// Opening, switching and closing the camera, shared by the stamp camera
/// and the vlog camera. Closes the camera when the app goes to the
/// background and opens it again on return, as Android expects.
mixin CameraHost<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  List<CameraDescription> cameras = [];
  int cameraIndex = 0;
  CameraController? camera;
  String? cameraError;
  bool _opening = false; // the permission prompt can trigger a second open

  ResolutionPreset get resolution;
  bool get withAudio;

  Future<void> startCamera() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => cameraError = 'No camera found on this phone.');
        return;
      }
      // Start with the back camera.
      final back = cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      cameraIndex = back < 0 ? 0 : back;
      await openCamera();
    } catch (e) {
      debugPrint('Camera: $e');
      if (mounted) setState(() => cameraError = 'The camera isn\'t available. Check that Dear Today may use it.');
    }
  }

  Future<void> openCamera() async {
    if (cameras.isEmpty || _opening) return;
    _opening = true;
    try {
      await _open();
    } finally {
      _opening = false;
    }
  }

  Future<void> _open() async {
    final old = camera;
    if (mounted) setState(() => camera = null);
    await old?.dispose();
    final c = CameraController(cameras[cameraIndex], resolution, enableAudio: withAudio);
    try {
      await c.initialize();
    } catch (e) {
      debugPrint('Camera: $e');
      await c.dispose();
      if (mounted) setState(() => cameraError = 'The camera isn\'t available. Check that Dear Today may use it.');
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      camera = c;
      cameraError = null;
    });
  }

  Future<void> switchCamera() async {
    if (cameras.length < 2) return;
    cameraIndex = (cameraIndex + 1) % cameras.length;
    await openCamera();
  }

  void stopCamera() {
    WidgetsBinding.instance.removeObserver(this);
    camera?.dispose();
    camera = null;
  }

  /// Called just before the camera is closed for the background.
  void onCameraPausing() {}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final c = camera;
      if (c == null) return;
      onCameraPausing();
      setState(() => camera = null);
      c.dispose();
    } else if (state == AppLifecycleState.resumed && camera == null && cameraError == null) {
      openCamera();
    }
  }
}
