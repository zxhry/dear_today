import 'package:flutter/material.dart';

import '../../data/journal_store.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/stamp.dart';
import '../../widgets/ui.dart';
import 'collections_screen.dart';
import 'stamp_screen.dart';

/// One collection's stamps, three to a row.
class CollectionScreen extends StatefulWidget {
  final CollectionRef ref;
  const CollectionScreen({super.key, required this.ref});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  bool _newestFirst = true;

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final store = JournalStore.instance;
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (!widget.ref.exists(store)) return const SizedBox.shrink(); // the set was just deleted
          final stamps = widget.ref.stamps(store);
          final shown = _newestFirst ? stamps : stamps.reversed.toList();
          final set = widget.ref.isMonth ? null : store.setById(widget.ref.setId);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 10, 20, 0),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        CircleIconButton(
                            icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => Navigator.pop(context)),
                        const Spacer(),
                        if (set != null)
                          CircleIconButton(
                            icon: Icons.more_horiz_rounded,
                            tooltip: 'Set options',
                            onTap: () async {
                              await showSetOptions(context, set);
                              if (context.mounted && store.setById(set.id) == null) Navigator.pop(context);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: PageTitle(
                            widget.ref.title(store),
                            size: 32,
                            subtitle: '${widget.ref.kind} · ${stampCount(stamps.length)}',
                          ),
                        ),
                        if (stamps.length > 1)
                          TextButton(
                            onPressed: () => setState(() => _newestFirst = !_newestFirst),
                            style: TextButton.styleFrom(
                              shape: StadiumBorder(side: BorderSide(color: t.border)),
                              backgroundColor: t.surf,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: Text(_newestFirst ? 'Newest first' : 'Oldest first',
                                style: Fonts.sans(12, t.text, weight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (stamps.isEmpty)
                      EmptyNote(
                        icon: Icons.local_post_office_outlined,
                        text: widget.ref.isMonth
                            ? 'No stamps this month yet. Tap + on the Stamps page to press one.'
                            : 'No stamps in this set yet. When you press a stamp, choose this set under "Add to collection".',
                      ),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 40),
                sliver: SliverGrid.builder(
                  itemCount: shown.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                  itemBuilder: (context, i) {
                    final s = shown[i];
                    final tilt = i % 3 == 1 ? 1.2 : (i % 3 == 2 ? -1.0 : 0.0);
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StampScreen(stampId: s.id))),
                      child: Semantics(
                        button: true,
                        label: 'Stamp from ${shortDate(s.takenAt)}',
                        child: Column(
                          children: [
                            Expanded(child: StampPhoto(stamp: s, tilt: tilt, aspect: 0.8, decodeWidth: 240)),
                            const SizedBox(height: 6),
                            Text('${s.takenAt.day} ${shortMonth(s.takenAt).toUpperCase()}',
                                style: Fonts.mono(10, t.muted)),
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
      ),
    );
  }
}
