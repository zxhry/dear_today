import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/stamp.dart';
import '../../widgets/vault_image.dart';
import '../diary/entry_screen.dart';
import '../stamps/stamp_screen.dart';
import '../vlog/vlog_screen.dart';

/// Opens the page for one moment: a note to read, a stamp, or the day reel.
void openMoment(BuildContext context, Moment m) {
  final Widget page = switch (m) {
    NoteMoment(:final entry) => EntryScreen(entryId: entry.id),
    StampMoment(:final stamp) => StampScreen(stampId: stamp.id),
    ClipsMoment(:final clips) => DayReelScreen(day: dayOnly(clips.first.recordedAt)),
  };
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

/// A day's moments as a timeline: the time on the left, a card on the right.
class DayTimeline extends StatelessWidget {
  final List<Moment> moments;
  const DayTimeline({super.key, required this.moments});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < moments.length; i++)
            MomentTile(moment: moments[i], last: i == moments.length - 1),
        ],
      );
}

class MomentTile extends StatelessWidget {
  final Moment moment;
  final bool last;
  const MomentTile({super.key, required this.moment, this.last = false});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final m = moment;
    final (kind, body) = switch (m) {
      NoteMoment(:final entry) => (
          [if (entry.prompt.isNotEmpty) 'PROMPT' else 'NOTE', if (entry.mood.isNotEmpty) entry.mood.toUpperCase()]
              .join(' · '),
          _NoteBody(entry: entry),
        ),
      StampMoment(:final stamp) => ('STAMP', _StampBody(stamp: stamp)),
      ClipsMoment c => ('VLOG', _ClipsBody(moment: c)),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 64,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Text(clockTime(m.at), style: Fonts.mono(11.5, t.text)),
                const SizedBox(height: 6),
                Expanded(child: Container(width: 1, color: last ? Colors.transparent : t.border)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: t.surf,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: t.border)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openMoment(context, m),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kind, style: Fonts.label(t.muted)),
                        const SizedBox(height: 8),
                        body,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBody extends StatelessWidget {
  final DiaryEntry entry;
  const _NoteBody({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    // No title: the note's own words, as a short preview.
    final preview = entry.text.trim().replaceAll(RegExp(r'\s*\n\s*'), ' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview.isNotEmpty)
          Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: Fonts.sans(13, t.muted, height: 1.5)),
        if (entry.photos.isNotEmpty) ...[
          if (preview.isNotEmpty) const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < entry.photos.length && i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          VaultImage(path: entry.photos[i], decodeWidth: 200, fallback: Container(color: t.surf2)),
                          if (i == 3 && entry.photos.length > 4)
                            Container(
                              color: Colors.black45,
                              alignment: Alignment.center,
                              child: Text('+${entry.photos.length - 4}', style: Fonts.sans(15, Colors.white)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StampBody extends StatelessWidget {
  final Stamp stamp;
  const _StampBody({required this.stamp});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Row(
      children: [
        SizedBox(width: 56, child: StampPhoto(stamp: stamp, holeRadius: 2.2, decodeWidth: 160, aspect: 0.8)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stamp.title.isEmpty ? 'A new stamp' : stamp.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: Fonts.sans(15, t.text, weight: FontWeight.w600)),
              if (stamp.place.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 13, color: t.muted),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(stamp.place,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.sans(12, t.muted)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ClipsBody extends StatelessWidget {
  final ClipsMoment moment;
  const _ClipsBody({required this.moment});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final n = moment.clips.length;
    return Row(
      children: [
        Container(
          width: 112,
          height: 63,
          decoration: BoxDecoration(color: DT.viewfinder, borderRadius: BorderRadius.circular(10)),
          child: Stack(
            children: [
              const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26)),
              Positioned(
                right: 6,
                bottom: 4,
                child: Text(shortDuration(moment.total), style: Fonts.mono(10, Colors.white)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n == 1 ? '1 clip' : '$n clips', style: Fonts.sans(15, t.text, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(n == 1 ? 'Tap to watch' : 'Until ${clockTime(moment.clips.last.recordedAt)}',
                  style: Fonts.sans(12, t.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// "2 notes · 5 clips · 1 stamp"
String momentSummary(List<Moment> moments) {
  var notes = 0, clips = 0, stamps = 0;
  for (final m in moments) {
    switch (m) {
      case NoteMoment():
        notes++;
      case StampMoment():
        stamps++;
      case ClipsMoment c:
        clips += c.clips.length;
    }
  }
  final parts = [
    if (notes > 0) notes == 1 ? '1 note' : '$notes notes',
    if (clips > 0) clips == 1 ? '1 clip' : '$clips clips',
    if (stamps > 0) stamps == 1 ? '1 stamp' : '$stamps stamps',
  ];
  return parts.isEmpty ? 'Nothing kept' : parts.join(' · ');
}
