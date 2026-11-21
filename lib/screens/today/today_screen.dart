import 'package:flutter/material.dart';

import '../../data/journal_store.dart';
import '../../data/settings_store.dart';
import '../../models/models.dart';
import '../../services/day_clock.dart';
import '../../services/prompts.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';
import '../diary/entry_screen.dart';
import '../diary/note_screen.dart';
import '../journal/moment_tile.dart';
import '../settings/settings_screen.dart';

/// The Today tab: today's question, a few numbers, and everything kept
/// today (notes, clips and stamps) on one timeline.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = JournalStore.instance;
    final settings = SettingsStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, settings, DayClock.instance]),
      builder: (context, _) {
        final today = DayClock.instance.today;
        final moments = store.momentsOn(today);
        final notes = [for (final m in moments) if (m is NoteMoment) m.entry];
        final clips = moments.whereType<ClipsMoment>().fold(0, (n, m) => n + m.clips.length);
        final stamps = moments.whereType<StampMoment>().length;
        final words = notes.fold(0, (n, e) => n + e.words);
        final streak = store.streak(today);
        final key = Prompts.dayKey(today);
        final prompt = Prompts.forDay(today, settings.promptSkipOn(key));
        DiaryEntry? answer;
        for (final e in notes) {
          if (e.prompt.isNotEmpty) answer = e;
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(20, pageTop(context), 20, 150),
          children: [
            PageHeader(
              label: '${weekdayName(today)} · ${today.day} ${shortMonth(today)}',
              title: 'Today',
              actions: [
                if (streak > 0)
                  HeaderChip(
                    icon: Icons.auto_awesome_outlined,
                    label: streak == 1 ? '1 day' : '$streak days',
                    tooltip: '$streak ${streak == 1 ? 'day' : 'days'} in a row',
                  ),
                CircleIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  size: 36,
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen(asPage: true))),
                ),
              ],
            ),
            const SizedBox(height: headerGap),
            _PromptCard(
              prompt: prompt,
              answer: answer,
              onWrite: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteScreen(prompt: prompt))),
              onAnother: () => settings.skipPrompt(key),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(value: '$clips', label: clips == 1 ? 'clip' : 'clips'),
                const SizedBox(width: 8),
                _Stat(value: '$stamps', label: stamps == 1 ? 'stamp' : 'stamps'),
                const SizedBox(width: 8),
                _Stat(value: '$words', label: words == 1 ? 'word' : 'words'),
              ],
            ),
            const SizedBox(height: 20),
            if (moments.isEmpty)
              const EmptyNote(
                icon: Icons.wb_twilight_outlined,
                text: 'Nothing kept yet today. Tap + to write a note, record a clip or collect a stamp.',
              )
            else
              DayTimeline(moments: moments),
          ],
        );
      },
    );
  }
}

class _PromptCard extends StatelessWidget {
  final String prompt;
  final DiaryEntry? answer; // today's note that answers a prompt, if any
  final VoidCallback onWrite;
  final VoidCallback onAnother;
  const _PromptCard({required this.prompt, required this.answer, required this.onWrite, required this.onAnother});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final done = answer;
    final light = t.fabFg;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.fabBg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(done == null ? 'PROMPT FOR TODAY' : 'TODAY\'S PROMPT · ANSWERED',
              style: Fonts.label(light.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          Text(done == null ? prompt : done.prompt, style: Fonts.serif(20, light).copyWith(height: 1.25)),
          const SizedBox(height: 14),
          Row(
            children: [
              _PillButton(
                label: done == null ? 'Write' : 'Read it',
                filled: true,
                onTap: done == null
                    ? onWrite
                    : () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => EntryScreen(entryId: done.id))),
              ),
              const SizedBox(width: 8),
              if (done == null) _PillButton(label: 'Another prompt', onTap: onAnother),
            ],
          ),
        ],
      ),
    );
  }
}

/// A button for the dark prompt card.
class _PillButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _PillButton({required this.label, this.filled = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Material(
      color: filled ? t.fabFg : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: filled ? t.fabFg : t.fabFg.withValues(alpha: 0.35))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(label,
              style: Fonts.sans(14, filled ? t.fabBg : t.fabFg, weight: filled ? FontWeight.w600 : FontWeight.w500)),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Fonts.mono(17, t.text)),
            Text(label, style: Fonts.sans(12, t.muted)),
          ],
        ),
      ),
    );
  }
}
