import 'package:flutter/material.dart';

import '../../data/journal_store.dart';
import '../../models/models.dart';
import '../../services/day_clock.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';
import '../../widgets/vault_image.dart';
import '../diary/photo_viewer_screen.dart';
import 'moment_tile.dart';

enum JournalFilter {
  all('All'),
  notes('Notes'),
  photos('Photos'),
  clips('Clips'),
  stamps('Stamps');

  final String label;
  const JournalFilter(this.label);
}

/// The Journal tab: a month calendar (darker days have more in them), the
/// chosen day's timeline, and search across notes, tags, moods and stamps.
class JournalScreen extends StatefulWidget {
  final String initialQuery;
  final bool asPage; // opened from a #tag, with a back button
  const JournalScreen({super.key, this.initialQuery = '', this.asPage = false});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late final _search = TextEditingController(text: widget.initialQuery);
  JournalFilter _filter = JournalFilter.all;
  late DateTime _month = monthOnly(DayClock.instance.today);
  DateTime? _picked; // null = today

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim().toLowerCase();

  bool _noteMatches(DiaryEntry e, String q) {
    if (q.startsWith('#')) return e.tags.any((tag) => tag.startsWith(q.substring(1)));
    return e.text.toLowerCase().contains(q) ||
        e.prompt.toLowerCase().contains(q) ||
        e.mood.toLowerCase() == q;
  }

  bool _stampMatches(Stamp s, String q, JournalStore store) {
    if (q.startsWith('#')) return false;
    return s.title.toLowerCase().contains(q) ||
        s.place.toLowerCase().contains(q) ||
        (store.setById(s.setId)?.name.toLowerCase().contains(q) ?? false);
  }

  /// Search results and filtered lists, newest first.
  List<Moment> _results(JournalStore store) {
    final q = _query;
    final f = _filter;
    final out = <Moment>[];
    if (f == JournalFilter.all || f == JournalFilter.notes) {
      for (final e in store.entries) {
        if (q.isEmpty || _noteMatches(e, q)) out.add(NoteMoment(e));
      }
    }
    if (f == JournalFilter.all || f == JournalFilter.stamps) {
      for (final s in store.stamps) {
        if (q.isEmpty || _stampMatches(s, q, store)) out.add(StampMoment(s));
      }
    }
    if (f == JournalFilter.clips || (f == JournalFilter.all && q.isNotEmpty && !q.startsWith('#'))) {
      for (final day in store.clipDays) {
        final label = '${longDate(day)} ${day.year}'.toLowerCase();
        if (q.isEmpty || label.contains(q)) out.add(ClipsMoment(store.clipsOn(day)));
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final store = JournalStore.instance;
    final pad = MediaQuery.paddingOf(context);
    final body = ListenableBuilder(
      listenable: Listenable.merge([store, DayClock.instance]),
      builder: (context, _) {
        final today = DayClock.instance.today;
        final browsing = _query.isEmpty && _filter == JournalFilter.all;
        final showPhotos = _query.isEmpty && _filter == JournalFilter.photos;
        final day = _picked ?? today;
        final daysKept = {
          for (final e in store.entries) dayOnly(e.at),
          for (final s in store.stamps) dayOnly(s.takenAt),
          ...store.clipDays,
        }.length;

        final children = <Widget>[
          if (widget.asPage) const TopBar(),
          PageHeader(label: daysKept == 1 ? '1 day kept' : '$daysKept days kept', title: 'Journal'),
          const SizedBox(height: headerGap),
          _SearchField(controller: _search, onChanged: () => setState(() {})),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                for (final f in JournalFilter.values) ...[
                  _FilterChip(label: f.label, on: f == _filter, onTap: () => setState(() => _filter = f)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ];

        if (browsing) {
          final moments = store.momentsOn(day);
          children.addAll([
            _Calendar(
              month: _month,
              today: today,
              picked: day,
              activity: store.activityIn(_month),
              onMonth: (m) => setState(() => _month = m),
              onPick: (d) => setState(() => _picked = d),
            ),
            const SizedBox(height: 22),
            Text(
              sameDay(day, today)
                  ? 'TODAY · ${momentSummary(moments).toUpperCase()}'
                  : '${shortDate(day).toUpperCase()} · ${momentSummary(moments).toUpperCase()}',
              style: Fonts.label(t.muted),
            ),
            const SizedBox(height: 12),
            if (moments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text('Nothing kept on this day.', style: Fonts.sans(14, t.muted)),
              )
            else
              DayTimeline(moments: moments),
          ]);
        } else if (showPhotos) {
          final photos = store.diaryPhotos;
          children.add(photos.isEmpty
              ? const EmptyNote(icon: Icons.photo_outlined, text: 'Photos you add to your notes show up here.')
              : _PhotoGrid(photos: photos, today: today));
        } else {
          final results = _results(store);
          if (results.isEmpty) {
            children.add(EmptyNote(
              icon: Icons.search_rounded,
              text: _query.isEmpty ? 'Nothing here yet.' : 'Nothing matches "${_search.text.trim()}".',
            ));
          } else {
            children.add(Text(results.length == 1 ? '1 RESULT' : '${results.length} RESULTS',
                style: Fonts.label(t.muted)));
            children.add(const SizedBox(height: 12));
            DateTime? lastDay;
            for (var i = 0; i < results.length; i++) {
              final m = results[i];
              final d = dayOnly(m.at);
              if (d != lastDay) {
                children.add(Padding(
                  padding: EdgeInsets.only(top: lastDay == null ? 0 : 8, bottom: 8),
                  child: Text(
                    d.year == today.year ? shortDate(d).toUpperCase() : '${shortDate(d).toUpperCase()} ${d.year}',
                    style: Fonts.label(t.text),
                  ),
                ));
                lastDay = d;
              }
              final nextSameDay = i + 1 < results.length && dayOnly(results[i + 1].at) == d;
              children.add(MomentTile(moment: m, last: !nextSameDay));
            }
          }
        }

        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
              20, pageTop(context, pushed: widget.asPage), 20, widget.asPage ? pad.bottom + 32 : 150),
          children: children,
        );
      },
    );
    return widget.asPage ? Scaffold(body: body) : body;
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      style: Fonts.sans(15, t.text),
      decoration: InputDecoration(
        filled: true,
        fillColor: t.surf2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        prefixIcon: Icon(Icons.search_rounded, color: t.muted, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: Icon(Icons.close_rounded, color: t.muted, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        hintText: 'Search notes, #tags, moods, places',
        hintStyle: Fonts.sans(15, t.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        color: on ? t.fabBg : t.surf,
        shape: StadiumBorder(side: BorderSide(color: on ? t.fabBg : t.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(label, style: Fonts.sans(13, on ? t.fabFg : t.text, weight: FontWeight.w500)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A month of days, shaded by how much was kept on each.
class _Calendar extends StatelessWidget {
  final DateTime month, today, picked;
  final Map<int, int> activity;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onPick;
  const _Calendar({
    required this.month,
    required this.today,
    required this.picked,
    required this.activity,
    required this.onMonth,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final first = DateTime(month.year, month.month);
    final daysIn = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // weeks start on Sunday
    final isThisMonth = sameMonth(month, today);

    Color fill(int n) => n == 0
        ? Colors.transparent
        : n == 1
            ? t.surf2
            : n <= 3
                ? t.dim
                : t.accent;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      decoration: BoxDecoration(
        color: t.surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(monthYear(month), style: Fonts.serif(20, t.text))),
              IconButton(
                tooltip: 'Previous month',
                icon: Icon(Icons.chevron_left_rounded, color: t.muted),
                onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: Icon(Icons.chevron_right_rounded, color: isThisMonth ? t.dim : t.muted),
                onPressed: isThisMonth ? null : () => onMonth(DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 6),
            child: Row(
              children: [
                for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Expanded(child: Center(child: Text(d, style: Fonts.mono(10, t.muted)))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (var d = 1; d <= daysIn; d++)
                  Builder(builder: (context) {
                    final date = DateTime(month.year, month.month, d);
                    final n = activity[d] ?? 0;
                    final future = date.isAfter(today);
                    final isPicked = sameDay(date, picked);
                    final isToday = sameDay(date, today);
                    final strong = n >= 4;
                    return Semantics(
                      button: !future,
                      selected: isPicked,
                      label: '${longDate(date)}, ${n == 0 ? 'nothing kept' : '$n kept'}',
                      child: GestureDetector(
                        onTap: future ? null : () => onPick(date),
                        child: Container(
                          decoration: BoxDecoration(
                            color: fill(n),
                            borderRadius: BorderRadius.circular(10),
                            border: isPicked ? Border.all(color: t.text, width: 2) : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$d',
                            style: Fonts.sans(
                              13,
                              future ? t.dim : (strong ? t.bg : t.text),
                              weight: isToday ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Less', style: Fonts.sans(11, t.muted)),
              const SizedBox(width: 6),
              for (final c in [t.surf2, t.dim, t.accent]) ...[
                Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 2),
              Text('More', style: Fonts.sans(11, t.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<(DiaryEntry, String)> photos;
  final DateTime today;
  const _PhotoGrid({required this.photos, required this.today});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
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
    );
  }
}
