import 'package:flutter/material.dart';

import '../../data/journal_store.dart';
import '../../models/models.dart';
import '../../services/day_clock.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';
import '../../widgets/vault_image.dart';
import 'note_screen.dart';
import 'photo_viewer_screen.dart';

/// The Diary tab: your day as a timeline, or all its photos at once.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  int _tab = 0; // 0 timeline, 1 photos

  void _open(DiaryEntry e) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => NoteScreen(editing: e)));

  String _dayLabel(DateTime day, DateTime today) {
    final date = '${shortWeekday(day)} ${day.day} ${shortMonth(day)}'.toUpperCase();
    if (sameDay(day, today)) return 'TODAY · $date';
    if (sameDay(day, today.subtract(const Duration(days: 1)))) return 'YESTERDAY · $date';
    return day.year == today.year ? date : '$date ${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final store = JournalStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, DayClock.instance]),
      builder: (context, _) {
        final entries = store.entries;
        final today = DayClock.instance.today;

        // The timeline: a day heading, then that day's entries (newest first).
        final rows = <Object>[];
        DateTime? lastDay;
        for (final e in entries) {
          final day = dayOnly(e.at);
          if (lastDay == null || day != lastDay) {
            rows.add(_dayLabel(day, today));
            lastDay = day;
          }
          rows.add(e);
        }
        final photos = store.diaryPhotos;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 14, 20, 0),
              sliver: SliverList.list(
                children: [
                  const SectionLabel('Dear Today'),
                  const SizedBox(height: 14),
                  PageTitle('My days', subtitle: entries.length == 1 ? '1 entry' : '${entries.length} entries'),
                  const SizedBox(height: 14),
                  UnderlineTabs(labels: const ['Timeline', 'Photos'], selected: _tab, onSelect: (i) => setState(() => _tab = i)),
                  const SizedBox(height: 14),
                  if (_tab == 0 && entries.isEmpty)
                    const EmptyNote(
                      icon: Icons.menu_book_outlined,
                      text: 'Nothing here yet. Tap the pen to write about your day, with or without a photo.',
                    ),
                  if (_tab == 1 && photos.isEmpty)
                    const EmptyNote(icon: Icons.photo_outlined, text: 'Photos you add to your notes show up here.'),
                ],
              ),
            ),
            if (_tab == 0)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
                sliver: SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    if (row is String) {
                      return Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 6, bottom: 12),
                        child: Text(row, style: Fonts.label(t.muted)),
                      );
                    }
                    final e = row as DiaryEntry;
                    return _EntryRow(entry: e, onTap: () => _open(e));
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
                sliver: SliverGrid.builder(
                  itemCount: photos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                  itemBuilder: (context, i) {
                    final (entry, path) = photos[i];
                    final label = sameDay(entry.at, today)
                        ? clockTime(entry.at)
                        : today.difference(dayOnly(entry.at)).inDays < 7
                            ? shortWeekday(entry.at).toUpperCase()
                            : '${entry.at.day} ${shortMonth(entry.at).toUpperCase()}';
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PhotoViewerScreen(photos: photos, initial: i)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            VaultImage(path: path, decodeWidth: 300, fallback: Container(color: t.surf2)),
                            Positioned(
                              left: 6,
                              bottom: 5,
                              child: Text(label,
                                  style: Fonts.mono(10, Colors.white)
                                      .copyWith(shadows: const [Shadow(blurRadius: 4, color: Colors.black54)])),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EntryRow extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  const _EntryRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final photos = entry.photos;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clockTime(entry.at), style: Fonts.mono(12, t.muted)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Container(width: 1, margin: const EdgeInsets.only(left: 6), color: t.border),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (photos.length == 1)
                      _photo(context, photos.first, height: 168)
                    else if (photos.length > 1)
                      SizedBox(
                        height: 120,
                        child: Row(
                          children: [
                            for (var i = 0; i < photos.length && i < 3; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _photo(context, photos[i]),
                                    if (i == 2 && photos.length > 3)
                                      Container(
                                        decoration: BoxDecoration(
                                            color: Colors.black45, borderRadius: BorderRadius.circular(14)),
                                        alignment: Alignment.center,
                                        child: Text('+${photos.length - 3}', style: Fonts.sans(18, Colors.white)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (photos.isNotEmpty && entry.text.isNotEmpty) const SizedBox(height: 10),
                    if (entry.text.isNotEmpty)
                      Text(entry.text, style: Fonts.mono(15, t.text, height: 1.55)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo(BuildContext context, String path, {double? height}) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: VaultImage(path: path, decodeWidth: 900, fallback: Container(color: context.dt.surf2)),
        ),
      );
}
