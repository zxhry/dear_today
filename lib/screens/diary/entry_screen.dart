import 'package:flutter/material.dart';

import '../../data/journal_store.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';
import '../../widgets/vault_image.dart';
import '../journal/day_screen.dart';
import '../journal/journal_screen.dart';
import 'note_screen.dart';
import 'photo_viewer_screen.dart';

/// A note to read: its photos, when it was written, the text, mood and tags.
/// Edit opens the note editor.
class EntryScreen extends StatelessWidget {
  final String entryId;
  const EntryScreen({super.key, required this.entryId});

  Future<void> _more(BuildContext context, DiaryEntry e) async {
    final t = context.dt;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.today_outlined, color: t.text),
              title: Text('See the whole day', style: Fonts.sans(15, t.text)),
              onTap: () => Navigator.pop(context, 'day'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: t.accent),
              title: Text('Delete note', style: Fonts.sans(15, t.accent)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'day') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DayScreen(day: dayOnly(e.at))));
    } else if (choice == 'delete') {
      final ok =
          await confirm(context, title: 'Delete this note?', message: 'The note and its photos will be gone for good.');
      if (ok) {
        await JournalStore.instance.deleteEntry(e);
        if (context.mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = JournalStore.instance;
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final e = store.entryById(entryId);
          if (e == null) return const SizedBox.shrink(); // deleted
          return _Reader(entry: e, onMore: () => _more(context, e));
        },
      ),
    );
  }
}

class _Reader extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onMore;
  const _Reader({required this.entry, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final e = entry;
    final pad = MediaQuery.paddingOf(context);
    final day = dayOnly(e.at);
    final others = JournalStore.instance.momentsOn(day).where((m) => !(m is NoteMoment && m.entry.id == e.id)).toList();
    final clipCount = others.whereType<ClipsMoment>().fold(0, (n, m) => n + m.clips.length);
    final stampCount = others.whereType<StampMoment>().length;
    final noteCount = others.whereType<NoteMoment>().length;
    final summary = [
      if (noteCount > 0) noteCount == 1 ? '1 note' : '$noteCount notes',
      if (clipCount > 0) clipCount == 1 ? '1 clip' : '$clipCount clips',
      if (stampCount > 0) stampCount == 1 ? '1 stamp' : '$stampCount stamps',
    ].join(' · ');

    return ListView(
      padding: EdgeInsets.fromLTRB(20, pageTop(context, pushed: true), 20, pad.bottom + 32),
      children: [
        TopBar(actions: [
          CircleIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit note',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteScreen(editing: e))),
          ),
          CircleIconButton(icon: Icons.more_horiz_rounded, tooltip: 'More', onTap: onMore),
        ]),
        if (e.photos.isNotEmpty) ...[
          _Photos(entry: e),
          const SizedBox(height: 16),
        ],
        Text(
          '${shortWeekday(e.at).toUpperCase()} ${e.at.day} ${shortMonth(e.at).toUpperCase()}'
          '${e.at.year == DateTime.now().year ? '' : ' ${e.at.year}'} · ${clockTime(e.at)}',
          style: Fonts.label(t.muted),
        ),
        if (e.prompt.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(e.prompt, style: Fonts.serif(16, t.accent).copyWith(fontStyle: FontStyle.italic, height: 1.35)),
        ],
        const SizedBox(height: 10),
        if (e.displayText.isNotEmpty)
          SelectableText(
            e.displayText,
            style: Fonts.serif(17, t.text).copyWith(height: 1.6, letterSpacing: 0),
          )
        else
          Text('No words, just photos.', style: Fonts.sans(14, t.muted)),
        if (e.mood.isNotEmpty || e.tags.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (e.mood.isNotEmpty) _Chip(label: e.mood, filled: true),
              for (final tag in e.tags)
                _Chip(
                  label: '#$tag',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => JournalScreen(initialQuery: '#$tag', asPage: true)),
                  ),
                ),
            ],
          ),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 22),
          Material(
            color: t.surf,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: t.border)),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DayScreen(day: day))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.today_outlined, size: 18, color: t.text),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Also from this day', style: Fonts.sans(14, t.text, weight: FontWeight.w600)),
                          const SizedBox(height: 1),
                          Text(summary, style: Fonts.sans(12, t.muted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: t.muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The note's photos, swipeable, with "1 / 3". Tap for full size.
class _Photos extends StatefulWidget {
  final DiaryEntry entry;
  const _Photos({required this.entry});

  @override
  State<_Photos> createState() => _PhotosState();
}

class _PhotosState extends State<_Photos> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final photos = widget.entry.photos;
    if (_i >= photos.length) _i = 0;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoViewerScreen(
                      photos: [for (final p in photos) (widget.entry, p)],
                      initial: i,
                    ),
                  ),
                ),
                child: VaultImage(path: photos[i], decodeWidth: 1080, fallback: Container(color: t.surf2)),
              ),
            ),
            if (photos.length > 1)
              Positioned(
                left: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(13)),
                    child: Text('${_i + 1} / ${photos.length}', style: Fonts.mono(11, Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  const _Chip({required this.label, this.filled = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Material(
      color: filled ? t.surf2 : t.surf,
      shape: StadiumBorder(side: BorderSide(color: filled ? t.surf2 : t.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label, style: Fonts.sans(13, t.text, weight: FontWeight.w500)),
        ),
      ),
    );
  }
}
