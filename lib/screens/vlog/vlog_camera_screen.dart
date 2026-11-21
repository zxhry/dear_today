import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../data/journal_store.dart';
import '../../data/settings_store.dart';
import '../../services/day_clock.dart';
import '../../services/gallery.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/camera_view.dart';
import '../../widgets/ui.dart';

/// The vlog camera: hold the phone sideways and record a few seconds.
/// The time sits in the middle of the picture, turned to read the right
/// way up in the landscape clip.
class VlogCameraScreen extends StatefulWidget {
  const VlogCameraScreen({super.key});

  @override
  State<VlogCameraScreen> createState() => _VlogCameraScreenState();
}

class _VlogCameraScreenState extends State<VlogCameraScreen> with WidgetsBindingObserver, CameraHost<VlogCameraScreen> {
  final _settings = SettingsStore.instance;
  Timer? _clock; // keeps the time on screen current
  Timer? _ticker; // runs while recording
  DateTime _now = DateTime.now();
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _stopping = false;
  bool _torch = false;

  // A clip that's been recorded but not kept yet: you watch it, then tap
  // ✓ to keep it or ✕ to record again.
  String? _pendingPath;
  DateTime? _pendingAt;
  int _pendingMs = 0;
  VideoPlayerController? _review;

  @override
  ResolutionPreset get resolution =>
      _settings.vlogQuality == '1080p' ? ResolutionPreset.veryHigh : ResolutionPreset.high;
  @override
  bool get withAudio => true;

  Duration get _limit => Duration(seconds: _settings.clipSeconds);

  @override
  void initState() {
    super.initState();
    startCamera();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _ticker?.cancel();
    _review?.dispose();
    final pending = _pendingPath;
    if (pending != null) JournalStore.deleteQuietly(pending); // never kept
    stopCamera();
    super.dispose();
  }

  @override
  void onCameraPausing() {
    // Leaving the app mid-recording drops that clip.
    _ticker?.cancel();
    _recording = false;
    _torch = false;
  }

  Future<void> _toggleTorch() async {
    final c = camera;
    if (c == null) return;
    _torch = !_torch;
    try {
      await c.setFlashMode(_torch ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      _torch = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _record() async {
    final c = camera;
    if (c == null || _stopping) return;
    if (_recording) return _stop();
    if (_pendingPath != null) return;
    try {
      // Always record a landscape (16:9) clip, the way you're holding the phone.
      try {
        await c.lockCaptureOrientation(_landscape);
      } catch (_) {}
      await c.startVideoRecording();
    } catch (e) {
      debugPrint('Start recording: $e');
      if (mounted) toast(context, 'Couldn\'t start recording. Try again.');
      return;
    }
    _startedAt = DateTime.now();
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _elapsed = DateTime.now().difference(_startedAt!);
      if (_elapsed >= _limit) {
        _stop();
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _stop() async {
    final c = camera;
    if (!_recording || _stopping || c == null) return;
    _stopping = true;
    _ticker?.cancel();
    try {
      final file = await c.stopVideoRecording();
      try {
        await c.unlockCaptureOrientation();
      } catch (_) {}
      final took = DateTime.now().difference(_startedAt!);
      final review = VideoPlayerController.file(File(file.path));
      await review.initialize();
      await review.setLooping(true);
      await review.play();
      _pendingPath = file.path;
      _pendingAt = _startedAt;
      _pendingMs = math.min(took.inMilliseconds, _limit.inMilliseconds);
      _review = review;
    } catch (e) {
      debugPrint('Stop recording: $e');
      if (mounted) toast(context, 'Couldn\'t record that clip.');
    } finally {
      _stopping = false;
      if (mounted) {
        setState(() {
          _recording = false;
          _elapsed = Duration.zero;
        });
      }
    }
  }

  /// Which way the phone is turned (landscape), from the camera's own sensor.
  DeviceOrientation get _landscape =>
      camera?.value.deviceOrientation == DeviceOrientation.landscapeRight
          ? DeviceOrientation.landscapeRight
          : DeviceOrientation.landscapeLeft;

  /// Turns for sideways things (the time), so they read upright in the clip.
  int get _turns => _landscape == DeviceOrientation.landscapeRight ? 3 : 1;

  Future<void> _keep() async {
    final path = _pendingPath;
    if (path == null || _stopping) return;
    _stopping = true;
    setState(() {});
    try {
      if (_settings.saveToGallery) await Gallery.savePlainFile(path, video: true);
      await JournalStore.instance.addClip(
        video: path,
        recordedAt: _pendingAt!,
        durationMs: _pendingMs,
        quality: _settings.vlogQuality,
      );
      if (mounted) toast(context, 'Clip saved.');
    } catch (e) {
      debugPrint('Keep clip: $e');
      if (mounted) toast(context, 'Couldn\'t save that clip.');
    } finally {
      _stopping = false;
      _clearReview();
    }
  }

  Future<void> _discard() async {
    final path = _pendingPath;
    _clearReview();
    if (path != null) await JournalStore.deleteQuietly(path);
  }

  void _clearReview() {
    _review?.dispose();
    _review = null;
    _pendingPath = null;
    _pendingAt = null;
    if (mounted) setState(() {});
  }

  Future<void> _qualitySheet() async {
    final t = context.dt;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vlog quality', style: Fonts.serif(24, t.text)),
                const SizedBox(height: 6),
                Text(
                  _settings.vlogQuality == '720p'
                      ? 'About 1.2 MB per 4s clip · recommended'
                      : 'About 3 MB per 4s clip · sharper',
                  style: Fonts.sans(13, t.muted),
                ),
                const SizedBox(height: 14),
                Segmented<String>(
                  mono: true,
                  options: const [('720p', '720p'), ('1080p', '1080p')],
                  value: _settings.vlogQuality,
                  onChanged: (q) async {
                    await _settings.setVlogQuality(q);
                    setSheet(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && camera != null && camera!.resolutionPreset != resolution) await openCamera();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final today = JournalStore.instance.clipsOn(DayClock.instance.today);
    final secs = _elapsed.inSeconds;
    final progress = _recording ? (_elapsed.inMilliseconds / _limit.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  CircleIconButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: _recording ? null : () => Navigator.pop(context)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: t.surf,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _recording ? const Color(0xFFE5402F) : t.dim,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                            _recording
                                ? 'REC 0:${secs.toString().padLeft(2, '0')}'
                                : _review != null
                                    ? 'KEEP THIS CLIP?'
                                    : 'READY',
                            style: Fonts.mono(13, t.text)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: t.surf,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: _torch ? 'Light on' : 'Light off',
                          onPressed: _toggleTorch,
                          icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, size: 18, color: t.text),
                        ),
                        IconButton(
                          tooltip: 'Vlog quality',
                          onPressed: _recording ? null : _qualitySheet,
                          icon: Icon(Icons.settings_outlined, size: 18, color: t.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // The viewfinder: a plain rectangle, edge to edge.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraFill(controller: camera, error: cameraError),
                  // The clip you just took, filling the viewfinder exactly like the
                  // live view: the landscape clip is turned on its side (you're
                  // holding the phone sideways) and cropped to fit.
                  if (_review != null)
                    LayoutBuilder(
                      builder: (context, box) {
                        final vc = _review!;
                        final size = vc.value.size;
                        return ClipRect(
                          child: RotatedBox(
                              quarterTurns: _turns,
                              child: SizedBox(
                                // Before turning, the area is the viewfinder on its side.
                                width: box.maxHeight,
                                height: box.maxWidth,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  clipBehavior: Clip.hardEdge,
                                  child: SizedBox(
                                    width: size.width == 0 ? 16 : size.width,
                                    height: size.height == 0 ? 9 : size.height,
                                    child: VideoPlayer(vc),
                                  ),
                                ),
                              ),
                            ),
                        );
                      },
                    ),
                  // The time, turned sideways like the clip will be.
                  Center(
                    child: RotatedBox(
                      quarterTurns: _turns,
                      child: Text(
                        clockTime(_pendingAt ?? _now),
                        style: Fonts.sans(20, Colors.white).copyWith(
                          letterSpacing: 0.8,
                          shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
                        ),
                      ),
                    ),
                  ),
                  // Clip length: 2s / 4s / 8s.
                  if (_review == null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(26)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final s in const [2, 4, 8])
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Semantics(
                                  button: true,
                                  selected: _settings.clipSeconds == s,
                                  label: '$s second clips',
                                  child: GestureDetector(
                                    onTap: _recording ? null : () => setState(() => _settings.setClipSeconds(s)),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _settings.clipSeconds == s ? Colors.white.withValues(alpha: 0.95) : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: RotatedBox(
                                        quarterTurns: _turns,
                                        child: Text('${s}s',
                                            style: Fonts.mono(13, _settings.clipSeconds == s ? const Color(0xFF190019) : Colors.white)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Record button, or ✕ / ✓ while reviewing a clip.
            if (_review != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  height: 84, // same height as the record button, so nothing jumps
                  child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Tooltip(
                      message: 'Record again',
                      child: Material(
                        color: t.surf,
                        shape: CircleBorder(side: BorderSide(color: t.border)),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _stopping ? null : _discard,
                          child: SizedBox(width: 64, height: 64, child: Icon(Icons.close_rounded, size: 28, color: t.text)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Tooltip(
                      message: 'Keep this clip',
                      child: Material(
                        color: t.fabBg,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _stopping ? null : _keep,
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: _stopping
                                ? Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: t.fabFg),
                                  )
                                : Icon(Icons.check_rounded, size: 28, color: t.fabFg),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              )
            else ...[
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: _recording ? 'Stop recording' : 'Record a clip',
              child: GestureDetector(
                onTap: _record,
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: CustomPaint(
                    painter: _RingPainter(progress: progress, track: t.dim, fill: t.accent),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: _recording ? 30 : 62,
                        height: _recording ? 30 : 62,
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(_recording ? 7 : 31),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ],
            const SizedBox(height: 14),

            // Today's clips, which clip this is, switch camera.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    button: true,
                    label: "Today's clips",
                    child: GestureDetector(
                      onTap: _recording ? null : () => Navigator.pop(context),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: t.surf2,
                              shape: BoxShape.circle,
                              border: Border.all(color: t.surf, width: 2),
                            ),
                            child: Icon(Icons.video_library_outlined, size: 20, color: t.text),
                          ),
                          if (today.isNotEmpty)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 20),
                                height: 20,
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                decoration: BoxDecoration(color: t.fabBg, borderRadius: BorderRadius.circular(10)),
                                alignment: Alignment.center,
                                child: Text('${today.length}', style: Fonts.sans(11, t.fabFg, weight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: t.surf,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: t.border),
                    ),
                    alignment: Alignment.center,
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: ordinal(today.length + 1), style: Fonts.mono(14, t.text)),
                      TextSpan(text: ' clip today', style: Fonts.sans(13, t.muted)),
                    ])),
                  ),
                  CircleIconButton(
                    icon: Icons.cameraswitch_outlined,
                    tooltip: 'Switch camera',
                    size: 48,
                    onTap: _recording || cameras.length < 2 ? null : switchCamera,
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

/// The ring around the record button, filling up while recording.
class _RingPainter extends CustomPainter {
  final double progress;
  final Color track, fill;
  _RingPainter({required this.progress, required this.track, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, stroke..color = track);
    if (progress > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, stroke..color = fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.track != track || old.fill != fill;
}
