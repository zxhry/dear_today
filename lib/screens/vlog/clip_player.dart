import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/journal_store.dart';
import '../../models/models.dart';
import '../../services/route_watch.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';

/// Plays one day's clips in a 16:9 frame, one at a time.
/// Tap the left or right side to move between clips, the middle to play
/// or pause, and long-press to delete a clip.
class ClipPlayer extends StatefulWidget {
  final List<VlogClip> clips; // in the order they play
  final ValueChanged<int>? onIndexChanged; // which clip is showing
  final bool showDots; // the "Clip 2 of 5" line under the player
  final String emptyText;
  // Plays the whole day by itself, from the first clip, while this is true
  // (the page is showing). It pauses when false or when another page opens on top.
  final bool autoPlay;
  const ClipPlayer({
    super.key,
    required this.clips,
    this.autoPlay = false,
    this.onIndexChanged,
    this.showDots = true,
    this.emptyText = 'No clips yet today.\nTap + to record a few seconds.',
  });

  @override
  State<ClipPlayer> createState() => ClipPlayerState();
}

class ClipPlayerState extends State<ClipPlayer> with RouteAware {
  // Autoplay starts from the first clip; otherwise show the latest one.
  late int _i = widget.autoPlay || widget.clips.isEmpty ? 0 : widget.clips.length - 1;
  VideoPlayerController? _vc;
  late bool _playingAll = widget.autoPlay;
  bool _ended = false;
  bool _covered = false; // another page is open on top
  int _token = 0; // ignores a slow load that's no longer wanted

  bool get _mayAutoPlay => widget.autoPlay && !_covered;

  @override
  void initState() {
    super.initState();
    final i = _i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onIndexChanged?.call(i);
    });
    _load(play: _mayAutoPlay);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeWatch.subscribe(this, route);
  }

  @override
  void didPushNext() {
    _covered = true;
    _vc?.pause();
  }

  @override
  void didPopNext() {
    _covered = false;
    if (widget.autoPlay && !_ended) {
      _playingAll = true;
      _vc?.play();
    }
  }

  @override
  void didUpdateWidget(ClipPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    final ids = widget.clips.map((c) => c.id).join();
    if (ids == old.clips.map((c) => c.id).join()) {
      // Same clips: just follow the page being shown or hidden.
      if (widget.autoPlay != old.autoPlay) {
        if (_mayAutoPlay) {
          playAll();
        } else {
          _playingAll = false;
          _vc?.pause();
        }
      }
      return;
    }
    // A clip was added (jump to it) or removed (stay close by).
    _i = widget.clips.length > old.clips.length
        ? widget.clips.length - 1
        : _i.clamp(0, widget.clips.isEmpty ? 0 : widget.clips.length - 1);
    _playingAll = _mayAutoPlay;
    final i = _i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onIndexChanged?.call(i);
    });
    _load(play: _mayAutoPlay);
  }

  @override
  void dispose() {
    routeWatch.unsubscribe(this);
    _token++;
    _vc?.removeListener(_tick);
    _vc?.dispose();
    super.dispose();
  }

  Future<void> _load({bool play = false}) async {
    final token = ++_token;
    final old = _vc;
    old?.removeListener(_tick);
    _vc = null; // (no setState here: this also runs from initState and didUpdateWidget)
    _ended = false;
    await old?.dispose();
    if (!mounted || token != _token) return;
    setState(() {});
    if (widget.clips.isEmpty) return;
    try {
      final file = await JournalStore.instance.openClip(widget.clips[_i]);
      final vc = VideoPlayerController.file(file);
      await vc.initialize();
      if (token != _token || !mounted) {
        await vc.dispose();
        return;
      }
      vc.addListener(_tick);
      setState(() => _vc = vc);
      // Don't start if the page was hidden or covered while this loaded.
      if (play && !_covered && (widget.autoPlay || _playingAll)) await vc.play();
    } catch (e) {
      debugPrint('Clip: $e');
    }
  }

  void _tick() {
    final v = _vc?.value;
    if (v == null || !mounted) return;
    final finished = v.isInitialized && !v.isPlaying && v.duration > Duration.zero && v.position >= v.duration;
    if (finished && !_ended) {
      _ended = true;
      if (_playingAll && _i < widget.clips.length - 1) {
        _go(_i + 1, play: true);
        return;
      }
      _playingAll = false;
    }
    setState(() {});
  }

  void _go(int i, {bool play = false}) {
    if (i < 0 || i >= widget.clips.length) return;
    setState(() => _i = i);
    widget.onIndexChanged?.call(i);
    _load(play: play);
  }

  /// Shows clip [i] (from the strip under the player). While autoplaying,
  /// it carries on through the rest of the day from there.
  void go(int i) {
    _playingAll = _mayAutoPlay;
    _go(i, play: _mayAutoPlay);
  }

  int get index => _i;

  /// Plays every clip of the day, back to back.
  void playAll() {
    if (widget.clips.isEmpty) return;
    _playingAll = true;
    _go(0, play: true);
  }

  Future<void> _togglePlay() async {
    final vc = _vc;
    if (vc == null) return;
    if (vc.value.isPlaying) {
      _playingAll = false;
      await vc.pause();
    } else {
      if (_ended) {
        await vc.seekTo(Duration.zero);
        _ended = false;
      }
      await vc.play();
    }
    if (mounted) setState(() {});
  }

  Widget _cornerButton(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.black45,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 19, color: Colors.white)),
          ),
        ),
      );

  Future<void> _deleteCurrent() async {
    if (widget.clips.isEmpty) return;
    final clip = widget.clips[_i];
    final ok = await confirm(context,
        title: 'Delete this clip?', message: 'The ${clockTime(clip.recordedAt)} clip will be gone for good.');
    if (ok) await JournalStore.instance.deleteClip(clip);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final clips = widget.clips;
    if (clips.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.emptyText,
            textAlign: TextAlign.center,
            style: Fonts.sans(14, t.muted, height: 1.45),
          ),
        ),
      );
    }
    final clip = clips[_i];
    final vc = _vc;
    final playing = vc?.value.isPlaying ?? false;
    final size = vc?.value.size ?? Size.zero;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: DT.viewfinder),
                if (vc != null && size.width > 0)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(vc)),
                  ),
                // The time it was recorded, small, in the middle.
                Center(
                  child: Text(
                    clockTime(clip.recordedAt),
                    style: Fonts.sans(15, Colors.white)
                        .copyWith(letterSpacing: 0.6, shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]),
                  ),
                ),
                // Tap zones: left = previous, middle = play/pause, right = next.
                Row(
                  children: [
                    Expanded(
                      flex: 35,
                      child: Semantics(
                        button: true,
                        label: 'Previous clip',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _go(_i - 1),
                          onLongPress: _deleteCurrent,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 30,
                      child: Semantics(
                        button: true,
                        label: playing ? 'Pause' : 'Play',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _togglePlay,
                          onLongPress: _deleteCurrent,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 35,
                      child: Semantics(
                        button: true,
                        label: 'Next clip',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _go(_i + 1),
                          onLongPress: _deleteCurrent,
                        ),
                      ),
                    ),
                  ],
                ),
                // One bar per clip, like stories: done, showing, still to come.
                if (clips.length > 1 && clips.length <= 24)
                  Positioned(
                    left: 12,
                    right: 64,
                    top: 12,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          for (var k = 0; k < clips.length; k++) ...[
                            if (k > 0) const SizedBox(width: 3),
                            Expanded(
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: k <= _i ? Colors.white : Colors.white38,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                // Delete this clip.
                Positioned(
                  right: 8,
                  top: 8,
                  child: Row(
                    children: [
                      _cornerButton(Icons.delete_outline_rounded, 'Delete clip', _deleteCurrent),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(shortDuration(clip.duration), style: Fonts.mono(11, Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.showDots) ...[
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (clips.length <= 12)
              for (var k = 0; k < clips.length; k++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: k == _i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: k == _i ? t.text : t.dim,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            const SizedBox(width: 10),
            Text('Clip ${_i + 1} of ${clips.length} · tap left or right', style: Fonts.mono(12, t.muted)),
          ],
        ),
        ],
      ],
    );
  }
}
