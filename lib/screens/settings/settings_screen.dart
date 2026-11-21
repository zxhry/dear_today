import 'package:flutter/material.dart';

import '../../data/journal_store.dart';
import '../../data/settings_store.dart';
import '../../security/app_lock.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';
import 'backup_flows.dart';
import 'storage_screen.dart';

/// Settings, opened from the gear on the Today page.
class SettingsScreen extends StatefulWidget {
  final bool asPage; // with a back button (it's no longer a tab)
  const SettingsScreen({super.key, this.asPage = true});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsStore.instance;
  late Future<StorageUsage> _usage = JournalStore.instance.usage();

  @override
  void initState() {
    super.initState();
    JournalStore.instance.addListener(_refreshUsage);
  }

  @override
  void dispose() {
    JournalStore.instance.removeListener(_refreshUsage);
    super.dispose();
  }

  void _refreshUsage() => setState(() => _usage = JournalStore.instance.usage());

  Future<void> _setLock(bool on) async {
    final lock = AppLock.instance;
    if (on && !await lock.isAvailable()) {
      if (mounted) toast(context, 'Set up a screen lock or fingerprint on your phone first.');
      return;
    }
    // Ask for the fingerprint/PIN either way, so nobody else can switch it off.
    if (await lock.verify(on ? 'Turn on app lock' : 'Turn off app lock')) await _settings.setLockEnabled(on);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final last = _settings.lastBackupAt;
        final pad = MediaQuery.paddingOf(context);
        final list = ListView(
          padding: EdgeInsets.fromLTRB(
              20, pageTop(context, pushed: widget.asPage), 20, widget.asPage ? pad.bottom + 32 : 150),
          children: [
            if (widget.asPage) const TopBar(),
            const PageHeader(label: 'Dear Today', title: 'Settings'),
            const SizedBox(height: headerGap),
            const SectionLabel('Appearance'),
            const SizedBox(height: 8),
            CardGroup(children: [
              SettingsRow(
                icon: Icons.light_mode_outlined,
                title: 'Theme',
                trailing: Segmented<ThemeMode>(
                  options: const [(ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark'), (ThemeMode.system, 'System')],
                  value: _settings.themeMode,
                  onChanged: _settings.setThemeMode,
                ),
              ),
            ]),
            const SizedBox(height: 18),
            const SectionLabel('Privacy'),
            const SizedBox(height: 8),
            CardGroup(children: [
              SettingsRow(
                icon: Icons.lock_outline_rounded,
                title: 'App lock',
                subtitle: 'Fingerprint or PIN to open',
                trailing: Switch(value: _settings.lockEnabled, onChanged: _setLock),
              ),
              const SettingsRow(
                icon: Icons.verified_user_outlined,
                title: 'Everything is encrypted',
                subtitle: 'Stamps, diary and vlog, on this phone',
              ),
            ]),
            const SizedBox(height: 18),
            const SectionLabel('Storage'),
            const SizedBox(height: 8),
            CardGroup(children: [
              FutureBuilder<StorageUsage>(
                future: _usage,
                builder: (context, snap) {
                  final u = snap.data;
                  return SettingsRow(
                    icon: Icons.folder_outlined,
                    title: 'Storage',
                    subtitle: u == null
                        ? 'Counting…'
                        : u.vlogBytes >= u.stampBytes && u.vlogBytes >= u.diaryBytes && u.vlogBytes > 0
                            ? '${fileSize(u.total)} · vlog uses the most'
                            : '${fileSize(u.total)} used',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageScreen())),
                  );
                },
              ),
            ]),
            const SizedBox(height: 18),
            const SectionLabel('Backup'),
            const SizedBox(height: 8),
            CardGroup(children: [
              SettingsRow(
                icon: Icons.upload_rounded,
                title: 'Export backup',
                subtitle: last == null
                    ? 'Password can\'t be reset if forgotten'
                    : 'Last: ${last.day} ${shortMonth(last)} ${last.year}',
                onTap: () => createBackupFlow(context),
              ),
              SettingsRow(
                icon: Icons.download_rounded,
                title: 'Restore from backup',
                onTap: () => restoreBackupFlow(context),
              ),
            ]),
            const SizedBox(height: 18),
            Center(child: Text('Dear Today · v2', style: Fonts.mono(11, t.muted))),
          ],
        );
        return widget.asPage ? Scaffold(body: list) : list;
      },
    );
  }
}
