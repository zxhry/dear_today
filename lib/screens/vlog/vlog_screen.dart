import 'package:flutter/material.dart';

import '../../data/journal_store.dart';
import '../../data/settings_store.dart';
import '../../models/models.dart';
import '../../services/day_clock.dart';
import '../../services/vlog_export.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';
import 'clip_player.dart';

String clipSummary(List<VlogClip> clips) {
  final total = clips.fold(Duration.zero, (sum, c) => sum + c.duration);
  return '${clips.length} ${clips.length == 1 ? 'clip' : 'clips'} · ${shortDuration(total)}';
}

/// The Day reel tab: today's clips playing as one reel, ready to save, with
/// earlier days below.
class VlogScreen extends StatelessWidget {
  final bool active; // the tab is showing, so the reel may play
  const VlogScreen({super.key, this.active = false});

  @override
  Widget build(BuildContext context) {
    final store = JournalStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, DayClock.instance]),
      builder: (context, _) {
        final today = DayClock.instance.today;
        final days = store.clipDays.where((d) => !sameDay(d, today)).toList();
        return ListView(
          padding: EdgeInsets.fromLTRB(20, pageTop(context), 20, 150),
          children: [
            _Reel(day: today, isToday: true, autoPlay: active),
            if (days.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionLabel('Earlier reels'),
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

/// One day's reel, opened from the list or from a timeline.
class DayReelScreen extends StatelessWidget {
  final DateTime day;
  const DayReelScreen({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final store = JournalStore.instance;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(20, pageTop(context, pushed: true), 20, pad.bottom + 32),
          children: [
            const TopBar(),
            _Reel(day: day, isToday: sameDay(day, DayClock.instance.today), autoPlay: true),
          ],
        ),
      ),
    );
  }
}

/// Title, player, the strip of clips, reel options and the save button.
class _Reel extends StatefulWidget {
  final DateTime day;
  final bool isToday;
  final bool autoPlay;
  const _Reel({required this.day, required this.isToday, required this.autoPlay});

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> {
  final _player = GlobalKey<ClipPlayerState>();
  int? _shown; // the clip in the player, as it reports it
  bool _saving = false;

  Future<void> _save(List<VlogClip> clips) async {
    if (_saving) return;
    setState(() => _saving = true);
    toast(context, 'Putting your reel together…');
    final s = SettingsStore.instance;
    final problem = await VlogExport.saveDay(
      clips,
      widget.day,
      showTime: s.reelShowTime,
      sound: s.reelSound,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    toast(context, problem ?? 'Your day reel is saved to the gallery.');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final s = SettingsStore.instance;
    final clips = JournalStore.instance.clipsOn(widget.day);
    final total = clips.fold(Duration.zero, (sum, c) => sum + c.duration);
    final shown = (_shown ?? clips.length - 1).clamp(0, clips.isEmpty ? 0 : clips.length - 1);
    final date = widget.isToday
        ? '${weekdayName(widget.day)} · ${widget.day.day} ${shortMonth(widget.day)}'
        : '${shortDate(widget.day)}${widget.day.year == DateTime.now().year ? '' : ' ${widget.day.year}'}';
    final count = clips.length == 1 ? '1 clip' : '${clips.length} clips';

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            label: '$date · $count',
            title: 'Day reel',
            actions: [HeaderChip(icon: Icons.schedule_rounded, label: shortDuration(total), tooltip: 'Reel length')],
          ),
          const SizedBox(height: headerGap),
          ClipPlayer(
            key: _player,
            clips: clips,
            showDots: false,
            autoPlay: widget.autoPlay,
            emptyText: widget.isToday ? 'No clips yet today.\nTap + to record a few seconds.' : 'No clips on this day.',
            onIndexChanged: (i) => setState(() => _shown = i),
          ),
          if (clips.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 66,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: clips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final on = i == shown;
                  return Semantics(
                    button: true,
                    selected: on,
                    label: 'Clip at ${clockTime(clips[i].recordedAt)}',
                    child: GestureDetector(
                      onTap: () => _player.currentState?.go(i),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 76,
                            height: 43,
                            decoration: BoxDecoration(
                              color: on ? DT.viewfinder : t.surf2,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: on ? t.text : Colors.transparent, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(shortDuration(clips[i].duration),
                                style: Fonts.mono(11, on ? Colors.white : t.muted)),
                          ),
                          const SizedBox(height: 5),
                          Text(clockTime(clips[i].recordedAt), style: Fonts.mono(10.5, on ? t.text : t.muted)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const SectionLabel('When you save it'),
            const SizedBox(height: 8),
            CardGroup(
              dividerIndent: 14,
              children: [
                SettingsRow(
                  title: 'Time in the middle',
                  subtitle: 'Small and light, over each clip',
                  trailing: Switch(value: s.reelShowTime, onChanged: s.setReelShowTime),
                ),
                SettingsRow(
                  title: 'Sound',
                  subtitle: s.reelSound ? 'Keeps each clip\'s own sound' : 'Silent, add music later',
                  trailing: Switch(value: s.reelSound, onChanged: s.setReelSound),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: _saving ? 'Saving…' : 'Save reel to gallery',
              icon: Icons.download_rounded,
              onTap: _saving ? null : () => _save(clips),
            ),
          ],
        ],
      ),
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
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DayReelScreen(day: day))),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 41,
                decoration: BoxDecoration(color: DT.viewfinder, borderRadius: BorderRadius.circular(7)),
                alignment: Alignment.center,
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day.year == DateTime.now().year ? shortDate(day) : '${shortDate(day)} ${day.year}',
                        style: Fonts.sans(15, t.text, weight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(clipSummary(clips), style: Fonts.sans(12, t.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.muted),
            ],
          ),
        ),
      ),
    );
  }
}
