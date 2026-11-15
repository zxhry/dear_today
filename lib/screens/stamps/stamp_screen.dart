import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/journal_store.dart';
import '../../models/models.dart';
import '../../security/app_lock.dart';
import '../../services/gallery.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/stamp.dart';
import '../../widgets/ui.dart';

/// One stamp, big, with its postmark.
class StampScreen extends StatelessWidget {
  final String stampId;
  const StampScreen({super.key, required this.stampId});

  Future<void> _share(BuildContext context, Stamp s) async {
    final copy = await Gallery.unlockedCopy(s.photoPath, 'stamp-${s.id}.jpg');
    try {
      await AppLock.instance.stepOutside(
        () => SharePlus.instance.share(ShareParams(files: [XFile(copy.path)], text: s.title.isEmpty ? null : s.title)),
      );
    } finally {
      await Gallery.discard(copy);
    }
  }

  Future<void> _more(BuildContext context, Stamp s) async {
    final t = context.dt;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.download_rounded, color: t.text),
              title: Text('Save to gallery', style: Fonts.sans(15, t.text)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: t.accent),
              title: Text('Delete stamp', style: Fonts.sans(15, t.accent)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'gallery') {
      final ok = await Gallery.saveStamp(s);
      if (context.mounted) toast(context, ok ? 'Saved to your gallery.' : 'Couldn\'t save to the gallery.');
    } else if (choice == 'delete') {
      final ok = await confirm(context, title: 'Delete this stamp?', message: 'It will be gone from Dear Today for good.');
      if (ok) {
        await JournalStore.instance.deleteStamp(s);
        if (context.mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final store = JournalStore.instance;
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.stampById(stampId);
          if (s == null) return const SizedBox.shrink();
          final set = store.setById(s.setId);
          final number = store.numberInMonth(s).toString().padLeft(3, '0');
          final width = math.min(270.0, MediaQuery.sizeOf(context).width - 110);
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    children: [
                      Row(
                        children: [
                          CircleIconButton(
                              icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => Navigator.pop(context)),
                          Expanded(
                            child: Text(
                              'No. $number · ${monthName(s.takenAt).toUpperCase()}',
                              textAlign: TextAlign.center,
                              style: Fonts.mono(12, t.muted, spacing: 1.2),
                            ),
                          ),
                          CircleIconButton(
                              icon: Icons.more_horiz_rounded, tooltip: 'More', onTap: () => _more(context, s)),
                        ],
                      ),
                      const SizedBox(height: 34),
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SizedBox(
                              width: width,
                              child: StampPhoto(stamp: s, holeRadius: 5, tilt: -1.5, decodeWidth: 1080),
                            ),
                            Positioned(
                              right: -40,
                              top: -20,
                              child: Transform.rotate(angle: 12 * math.pi / 180, child: Postmark(when: s.takenAt)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(s.title.isEmpty ? 'Untitled stamp' : s.title, style: Fonts.serif(28, t.text)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (s.place.isNotEmpty) MetaChip(icon: Icons.place_outlined, label: s.place),
                          MetaChip(icon: Icons.calendar_view_month_outlined, label: monthYear(s.takenAt)),
                          if (set != null) MetaChip(icon: Icons.folder_outlined, label: set.name),
                          const MetaChip(icon: Icons.lock_outline_rounded, label: 'Encrypted'),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Edit',
                          icon: Icons.edit_outlined,
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => StampEditSheet(stamp: s),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryButton(
                            label: 'Share stamp', icon: Icons.ios_share_rounded, onTap: () => _share(context, s)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Change a stamp's caption, place and set.
class StampEditSheet extends StatefulWidget {
  final Stamp stamp;
  const StampEditSheet({super.key, required this.stamp});

  @override
  State<StampEditSheet> createState() => _StampEditSheetState();
}

class _StampEditSheetState extends State<StampEditSheet> {
  late final _title = TextEditingController(text: widget.stamp.title);
  late final _place = TextEditingController(text: widget.stamp.place);
  late String? _setId = widget.stamp.setId;

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await JournalStore.instance.updateStamp(widget.stamp.copyWith(
      title: _title.text.trim(),
      place: _place.text.trim(),
      setId: _setId,
      clearSet: _setId == null,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final sets = JournalStore.instance.sets;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + MediaQuery.viewPaddingOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit stamp', style: Fonts.serif(24, t.text)),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Caption'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _place,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Place'),
          ),
          const SizedBox(height: 16),
          Text('Set', style: Fonts.sans(12, t.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('None'),
                selected: _setId == null,
                onSelected: (_) => setState(() => _setId = null),
              ),
              for (final set in sets)
                ChoiceChip(
                  label: Text(set.name),
                  selected: _setId == set.id,
                  onSelected: (_) => setState(() => _setId = set.id),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: PrimaryButton(label: 'Save', onTap: _save)),
        ],
      ),
    );
  }
}
