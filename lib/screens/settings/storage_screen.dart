import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/journal_store.dart';
import '../../data/settings_store.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';
import 'backup_flows.dart';

/// How much space Dear Today takes, and ways to keep it small.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final _settings = SettingsStore.instance;
  final _store = JournalStore.instance;
  StorageUsage? _usage;
  int _oldBytes = 0;

  DateTime get _cutoff {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 3, now.day);
  }

  @override
  void initState() {
    super.initState();
    _store.addListener(_count);
    _count();
  }

  @override
  void dispose() {
    _store.removeListener(_count);
    super.dispose();
  }

  Future<void> _count() async {
    final usage = await _store.usage();
    final old = await JournalStore.sizeOf(_store.clipsOlderThan(_cutoff).map((c) => c.path));
    if (mounted) {
      setState(() {
        _usage = usage;
        _oldBytes = old;
      });
    }
  }

  Future<void> _freeUp() async {
    final old = _store.clipsOlderThan(_cutoff);
    if (old.isEmpty) return;
    final ok = await confirm(
      context,
      title: 'Remove ${old.length} old ${old.length == 1 ? 'clip' : 'clips'}?',
      message: 'Vlog clips from before ${_cutoff.day} ${shortMonth(_cutoff)} will be removed from this phone. '
          'They\'re only kept if you exported a backup first.',
      action: 'Remove',
    );
    if (!ok) return;
    final freed = await _store.removeClips(old);
    if (mounted) toast(context, 'Freed ${fileSize(freed)}.');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final u = _usage;
    return Scaffold(
      body: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(
              20, pageTop(context, pushed: true), 20, MediaQuery.paddingOf(context).bottom + 40),
          children: [
            const TopBar(),
            PageHeader(label: u == null ? 'Counting…' : '${fileSize(u.total)} used on this phone', title: 'Storage'),
            const SizedBox(height: headerGap),
            if (u != null) ...[
              // One bar, split into vlog, diary and stamps.
              Semantics(
                label: 'Vlog ${fileSize(u.vlogBytes)}, diary ${fileSize(u.diaryBytes)}, stamps ${fileSize(u.stampBytes)}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox(
                    height: 14,
                    child: u.total == 0
                        ? Container(color: t.surf2)
                        : Row(
                            children: [
                              for (final (bytes, color) in [(u.vlogBytes, t.seg3), (u.diaryBytes, t.seg2), (u.stampBytes, t.seg1)])
                                if (bytes > 0)
                                  Expanded(
                                    flex: math.max(8, bytes * 1000 ~/ u.total), // tiny parts still show
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 3),
                                      color: color,
                                    ),
                                  ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              CardGroup(
                dividerIndent: 38,
                children: [
                  _legend(t.seg3, 'Vlog', '${u.clipCount} ${u.clipCount == 1 ? 'clip' : 'clips'} · ${_settings.vlogQuality}', u.vlogBytes),
                  _legend(t.seg2, 'Diary', '${u.diaryPhotoCount} ${u.diaryPhotoCount == 1 ? 'photo' : 'photos'}', u.diaryBytes),
                  _legend(t.seg1, 'Stamps', '${u.stampCount} ${u.stampCount == 1 ? 'stamp' : 'stamps'}', u.stampBytes),
                ],
              ),
            ],
            const SizedBox(height: 18),
            const SectionLabel('Quality'),
            const SizedBox(height: 8),
            CardGroup(
              dividerIndent: 14,
              children: [
                SettingsRow(
                  title: 'Vlog quality',
                  subtitle: _settings.vlogQuality == '720p'
                      ? 'About 1.2 MB per 4s clip · recommended'
                      : 'About 3 MB per 4s clip · sharper',
                  trailing: Segmented<String>(
                    mono: true,
                    options: const [('720p', '720p'), ('1080p', '1080p')],
                    value: _settings.vlogQuality,
                    onChanged: _settings.setVlogQuality,
                  ),
                ),
                SettingsRow(
                  title: 'Also save to gallery',
                  subtitle: _settings.saveToGallery
                      ? 'New stamps and clips also go to your gallery, unencrypted'
                      : 'Off keeps one encrypted copy only',
                  trailing: Switch(value: _settings.saveToGallery, onChanged: _settings.setSaveToGallery),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Free up space', style: Fonts.sans(15, t.text, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    'Remove vlog clips older than 3 months from this phone. Export a backup first so you keep them.',
                    style: Fonts.sans(13, t.muted, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SecondaryButton(label: 'Export backup', height: 46, onTap: () => createBackupFlow(context)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: _oldBytes == 0 ? 'No old clips to remove' : 'Free ${fileSize(_oldBytes)}',
                      height: 46,
                      onTap: _oldBytes == 0 ? null : _freeUp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String name, String note, int bytes) {
    final t = context.dt;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Fonts.sans(15, t.text, weight: FontWeight.w500)),
                Text(note, style: Fonts.sans(12, t.muted)),
              ],
            ),
          ),
          Text(fileSize(bytes), style: Fonts.mono(13, t.text)),
        ],
      ),
    );
  }
}
