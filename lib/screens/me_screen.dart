import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../security/app_lock.dart';
import '../theme.dart';
import 'backup_flows.dart';

/// The "Me" tab: privacy and app settings.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  Future<void> _toggleLock(BuildContext context, bool turnOn) async {
    final messenger = ScaffoldMessenger.of(context);
    final lock = AppLock.instance;

    if (!await lock.isAvailable()) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Set up a fingerprint, face or screen lock in your phone settings first.'),
      ));
      return;
    }
    // Ask for the owner both to turn it on AND off, so someone borrowing
    // your phone can't simply switch the lock off.
    final ok = await lock.verify(turnOn ? 'Confirm to turn on app lock' : 'Confirm to turn off app lock');
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('App lock wasn\'t changed')));
      return;
    }
    await SettingsStore.instance.setLockEnabled(turnOn);
    messenger.showSnackBar(SnackBar(
      content: Text(turnOn
          ? 'App lock is on. Dear Today will ask for you when it opens.'
          : 'App lock is off'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        final lockOn = SettingsStore.instance.lockEnabled;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Text('Me', style: AppText.hand(40)),
              const SizedBox(height: 4),
              Text('Keep your letters yours.', style: AppText.body(14, color: AppColors.inkSoft)),
              const SizedBox(height: 22),
              const _SectionTitle('Privacy'),
              _Card(
                children: [
                  SwitchListTile(
                    value: lockOn,
                    onChanged: (v) => _toggleLock(context, v),
                    activeTrackColor: AppColors.accent,
                    secondary: const Icon(Icons.fingerprint, color: AppColors.ink),
                    title: Text('App lock', style: AppText.body(15, weight: FontWeight.w800)),
                    subtitle: Text(
                      'Ask for your fingerprint, face or phone PIN when opening Dear Today, '
                      'and after ${AppLock.grace.inSeconds} seconds away.',
                      style: AppText.body(12, weight: FontWeight.w500, color: AppColors.inkSoft),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.enhanced_encryption_outlined, color: AppColors.ink),
                    title: Text('Encryption', style: AppText.body(15, weight: FontWeight.w800)),
                    subtitle: Text(
                      'Letters and photos are scrambled with AES-256. The key is kept in '
                      'your phone\'s secure hardware, never in the app\'s files.',
                      style: AppText.body(12, weight: FontWeight.w500, color: AppColors.inkSoft),
                    ),
                    trailing: const Icon(Icons.verified_user, color: AppColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _SectionTitle('Backup'),
              _Card(
                children: [
                  ListTile(
                    leading: const Icon(Icons.backup_outlined, color: AppColors.ink),
                    title: Text('Create a backup', style: AppText.body(15, weight: FontWeight.w800)),
                    subtitle: Text(
                      'Lock all letters and photos with a password, then save the file anywhere.',
                      style: AppText.body(12, weight: FontWeight.w500, color: AppColors.inkSoft),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.ink),
                    onTap: () => createBackupFlow(context),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore, color: AppColors.ink),
                    title: Text('Restore from a backup', style: AppText.body(15, weight: FontWeight.w800)),
                    subtitle: Text(
                      'Add letters from a .dtb file. Nothing here is deleted.',
                      style: AppText.body(12, weight: FontWeight.w500, color: AppColors.inkSoft),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.ink),
                    onTap: () => restoreBackupFlow(context),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _SectionTitle('Coming soon'),
              const _Card(
                children: [
                  _SoonTile(
                    icon: Icons.notifications_none,
                    title: 'Daily reminder',
                    subtitle: 'A gentle nudge to write to today.',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text.toUpperCase(),
          style: AppText.body(12, weight: FontWeight.w800, color: AppColors.inkSoft).copyWith(letterSpacing: 1.4)),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.ink.withValues(alpha: 0.12)),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _SoonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  const _SoonTile({required this.icon, required this.title, required this.subtitle, this.tag = 'Soon'});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: false,
      leading: Icon(icon, color: AppColors.inkSoft),
      title: Text(title, style: AppText.body(15, weight: FontWeight.w800, color: AppColors.inkSoft)),
      subtitle: Text(subtitle, style: AppText.body(12, weight: FontWeight.w500, color: AppColors.inkSoft)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inkSoft, width: 1.2),
        ),
        child: Text(tag, style: AppText.body(11, weight: FontWeight.w800, color: AppColors.inkSoft)),
      ),
    );
  }
}
