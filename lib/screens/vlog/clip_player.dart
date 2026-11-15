import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/journal_store.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';

/// Plays one day's clips in a 16:9 frame, one at a time.
/// Tap the left or right side to move between clips, the middle to play
/// or pause, and long-press to delete a clip.
class ClipPlayer extends StatefulWidget {
  final List<VlogClip> clips; // oldest first
  const ClipPlayer({super.key, required this.clips});

  @override
  State<ClipPlayer> createState() => ClipPlayerState();
}

class ClipPlayerState extends State<ClipPlayer> {
  late int _i = widget.clips.isEmpty ? 0 : widget.clips.length - 1; // start on the latest clip
  VideoPlayerController? _vc;
  bool _playingAll = false;
  bool _ended = false;
  int _token = 0; // ignores a slow load that's no longer wanted

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ClipPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    final ids = widget.clips.map((c) => c.id).join();
    if (ids == old.clips.map((c) => c.id).join()) return;
    // A clip was added (jump to it) or removed (stay close by).
    _i = widget.clips.length > old.clips.length
        ? widget.clips.length - 1
        : _i.clamp(0, widget.clips.isEmpty ? 0 : widget.clips.length - 1);
    _playingAll = false;
    _load();
  }

  @override
  void dispose() {
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
      if (play) await vc.play();
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
    _load(play: play);
  }

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
            'No clips yet today.\nTap the camera button to record a few seconds.',
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
    );
  }
}
