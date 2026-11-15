import 'package:flutter/material.dart';

import '../../data/journal_store.dart';
import '../../models/models.dart';
import '../../services/day_clock.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';
import 'clip_player.dart';
import '../../services/vlog_export.dart';

String clipSummary(List<VlogClip> clips) {
  final total = clips.fold(Duration.zero, (sum, c) => sum + c.duration);
  return '${clips.length} ${clips.length == 1 ? 'clip' : 'clips'} · ${shortDuration(total)}';
}

/// The Vlog tab: today's clips in one player, earlier days below.
class VlogScreen extends StatelessWidget {
  const VlogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = JournalStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, DayClock.instance]),
      builder: (context, _) {
        final today = DayClock.instance.today;
        final days = store.clipDays.where((d) => !sameDay(d, today)).toList();
        return ListView(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 14, 20, 150),
          children: [
            const SectionLabel('Dear Today'),
            const SizedBox(height: 14),
            _DayPlayer(day: today, title: 'Vlog', isToday: true),
            if (days.isNotEmpty) ...[
              const SizedBox(height: 26),
              const SectionLabel('Earlier'),
              const SizedBox(height: 10),
              for (final d in days) ...[
                _DayRow(day: d),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// A day's title, its "Play all" button and the player.
class _DayPlayer extends StatefulWidget {
  final DateTime day;
  final String title;
  final bool isToday; // the Vlog tab's own player (says "today")
  const _DayPlayer({required this.day, required this.title, this.isToday = false});

  @override
  State<_DayPlayer> createState() => _DayPlayerState();
}

class _DayPlayerState extends State<_DayPlayer> {
  final _player = GlobalKey<ClipPlayerState>();
  bool _saving = false;

  /// Joins all of this day's clips into one video and saves it to the gallery.
  Future<void> _saveDay(List<VlogClip> clips) async {
    if (_saving) return;
    setState(() => _saving = true);
    toast(context, 'Putting your vlog together…');
    final problem = await VlogExport.saveDay(clips, widget.day);
    if (!mounted) return;
    setState(() => _saving = false);
    toast(context, problem ?? 'Your day\'s vlog is saved to the gallery.');
  }

  @override
  Widget build(BuildContext context) {
    final clips = JournalStore.instance.clipsOn(widget.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: PageTitle(
                widget.title,
                size: widget.isToday ? 36 : 34,
                subtitle: clips.isEmpty
                    ? (widget.isToday ? 'No clips yet today' : 'No clips')
                    : '${clipSummary(clips)}${widget.isToday ? ' today' : ''}',
              ),
            ),
            CircleIconButton(
              icon: _saving ? Icons.hourglass_top_rounded : Icons.download_rounded,
              tooltip: 'Save the day\'s vlog to the gallery',
              onTap: clips.isEmpty || _saving ? null : () => _saveDay(clips),
            ),
            const SizedBox(width: 8),
            PrimaryButton(
              label: 'Play all',
              icon: Icons.play_arrow_rounded,
              height: 44,
              onTap: clips.isEmpty ? null : () => _player.currentState?.playAll(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipPlayer(key: _player, clips: clips),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  final DateTime day;
  const _DayRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final clips = JournalStore.instance.clipsOn(day);
    return Material(
      color: t.surf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DayClipsScreen(day: day))),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 41,
                decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(7)),
                alignment: Alignment.center,
                child: Text(clockTime(clips.first.recordedAt), style: Fonts.mono(11, t.text)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortDate(day), style: Fonts.sans(15, t.text, weight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(clipSummary(clips), style: Fonts.sans(12, t.muted)),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: t.surf2, shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded, size: 20, color: t.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An earlier day's clips.
class DayClipsScreen extends StatelessWidget {
  final DateTime day;
  const DayClipsScreen({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final store = JournalStore.instance;
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 10, 20, MediaQuery.paddingOf(context).bottom + 40),
          children: [
            Row(
              children: [
                CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),
            _DayPlayer(day: day, title: shortDate(day)),
          ],
        ),
      ),
    );
  }
}
