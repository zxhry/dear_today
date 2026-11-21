import 'package:flutter/material.dart';

import '../../data/journal_store.dart';
import '../../models/models.dart';
import '../../services/day_clock.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/stamp.dart';
import '../../widgets/ui.dart';
import 'collection_screen.dart';

/// Which collection a screen is showing: a month's sheet, or a set you made.
class CollectionRef {
  final DateTime? month;
  final String? setId;
  const CollectionRef.month(DateTime this.month) : setId = null;
  const CollectionRef.set(String this.setId) : month = null;

  bool get isMonth => month != null;
  String get kind => isMonth ? 'Monthly sheet' : 'Set';

  String title(JournalStore s) => isMonth ? monthYear(month!) : (s.setById(setId)?.name ?? 'Set');

  List<Stamp> stamps(JournalStore s) => isMonth ? s.stampsInMonth(month!) : s.stampsInSet(setId!);

  /// False once a set has been deleted.
  bool exists(JournalStore s) => isMonth || s.setById(setId) != null;
}

String stampCount(int n) => n == 1 ? '1 stamp' : '$n stamps';

/// The Stamps tab: every monthly sheet and every set.
class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  Future<void> _newSet(BuildContext context) async {
    final name = await askText(context, title: 'New set', hint: 'Coffee runs, Sky watch…', action: 'Create');
    if (name != null) await JournalStore.instance.addSet(name);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final store = JournalStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, DayClock.instance]),
      builder: (context, _) {
        // This month's sheet is always there, even before its first stamp.
        final thisMonth = monthOnly(DayClock.instance.today);
        final months = {thisMonth, ...store.stampMonths}.toList()..sort((a, b) => b.compareTo(a));
        final refs = [
          for (final m in months) CollectionRef.month(m),
          for (final s in store.sets) CollectionRef.set(s.id),
        ];
        return ListView(
          padding: EdgeInsets.fromLTRB(20, pageTop(context), 20, 150),
          children: [
            PageHeader(
              label: '${stampCount(store.stamps.length)} · ${refs.length} '
                  '${refs.length == 1 ? 'collection' : 'collections'}',
              title: 'Stamps',
              actions: [HeaderChip(icon: Icons.add_rounded, label: 'New set', onTap: () => _newSet(context))],
            ),
            const SizedBox(height: headerGap),
            for (final ref in refs) ...[
              _CollectionCard(ref: ref),
              const SizedBox(height: 10),
            ],
            if (store.stamps.isEmpty)
              Text(
                'Tap + to press your first stamp: a nice place, a good coffee, the sky on the way home.',
                textAlign: TextAlign.center,
                style: Fonts.sans(13, t.muted, height: 1.45),
              ),
          ],
        );
      },
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final CollectionRef ref;
  const _CollectionCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final store = JournalStore.instance;
    final stamps = ref.stamps(store);
    return Material(
      color: t.surf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: t.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionScreen(ref: ref))),
        onLongPress: ref.isMonth ? null : () => showSetOptions(context, store.setById(ref.setId)!),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              SizedBox(
                width: 62,
                height: 76,
                child: stamps.isEmpty
                    ? const EmptyStamp()
                    : StampPhoto(stamp: stamps.first, holeRadius: 2.4, decodeWidth: 160, aspect: 49 / 63),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(ref.isMonth ? Icons.calendar_view_month_outlined : Icons.folder_outlined,
                            size: 14, color: t.muted),
                        const SizedBox(width: 6),
                        Text(ref.kind, style: Fonts.sans(12, t.muted)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(ref.title(store),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.serif(24, t.text)),
                    const SizedBox(height: 2),
                    Text(stampCount(stamps.length), style: Fonts.sans(13, t.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rename or delete a set (long-press a set, or its ⋯ button).
Future<void> showSetOptions(BuildContext context, StampSet set) async {
  final t = context.dt;
  final store = JournalStore.instance;
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit_outlined, color: t.text),
            title: Text('Rename set', style: Fonts.sans(15, t.text)),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: t.accent),
            title: Text('Delete set', style: Fonts.sans(15, t.accent)),
            subtitle: Text('Its stamps stay on their monthly sheets', style: Fonts.sans(12, t.muted)),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'rename') {
    final name = await askText(context, title: 'Rename set', initial: set.name);
    if (name != null) await store.renameSet(set, name);
  } else if (choice == 'delete') {
    final ok = await confirm(context,
        title: 'Delete "${set.name}"?', message: 'The set goes away, but its stamps stay on their monthly sheets.');
    if (ok) await store.deleteSet(set);
  }
}
