import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/letter_store.dart';
import '../data/settings_store.dart';
import '../models/letter.dart';
import '../security/app_lock.dart';
import '../theme.dart';
import '../utils/dates.dart';
import '../widgets/stamp.dart';
import '../widgets/vault_image.dart';
import '../services/reminders.dart';
import 'backup_flows.dart';

const appVersion = '1.0.0'; // keep in step with "version:" in pubspec.yaml

/// The "Me" tab: you, your stats, how the app looks, privacy and backups.
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
      content: Text(turnOn ? 'App lock is on. Dear Today will ask for you when it opens.' : 'App lock is off'),
    ));
  }

  Future<void> _editName(BuildContext context) async {
    final settings = SettingsStore.instance;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: settings.name),
    );
    if (name != null) {
      await settings.setName(name);
      await Reminders.reschedule(); // reminders greet you by name
      await Reminders.rescheduleMail();
    }
  }

  Future<void> _toggleReminder(BuildContext context, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    if (on && !await Reminders.requestPermission()) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Notifications are off for Dear Today. Allow them in your phone settings to get reminders.'),
      ));
      return;
    }
    await SettingsStore.instance.setReminder(on: on);
    await Reminders.reschedule();
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final s = SettingsStore.instance;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
      helpText: 'Remind me at',
    );
    if (picked == null) return;
    await s.setReminder(on: true, hour: picked.hour, minute: picked.minute);
    await Reminders.reschedule();
  }

  Future<void> _changeAvatar(BuildContext context) async {
    final settings = SettingsStore.instance;
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Profile picture', style: AppText.hand(26)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_outlined, color: AppColors.ink),
              title: Text('Choose from gallery', style: AppText.body(15, weight: FontWeight.w700)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.ink),
              title: Text('Take a photo', style: AppText.body(15, weight: FontWeight.w700)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (settings.avatarPath != null)
              ListTile(
                leading: const Icon(Icons.sentiment_satisfied_alt_outlined, color: AppColors.ink),
                title: Text('Use the little smiley', style: AppText.body(15, weight: FontWeight.w700)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') {
      await settings.removeAvatar();
      return;
    }
    try {
      final file = await AppLock.instance.stepOutside(
        () => ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 600,
          imageQuality: 85,
        ),
      );
      if (file != null) await settings.setAvatarFrom(file.path);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Couldn\'t change the picture: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([SettingsStore.instance, LetterStore.instance]),
      builder: (context, _) {
        final s = SettingsStore.instance;
        final store = LetterStore.instance;
        final now = DateTime.now();

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 28),
            children: [
              Text('Me', style: AppText.hand(34)),
              const SizedBox(height: 18),
              _ProfileCard(
                name: s.name,
                avatarPath: s.avatarPath,
                since: store.firstLetterDate,
                onEdit: () => _editName(context),
                onAvatar: () => _changeAvatar(context),
              ),
              const SizedBox(height: 22),

              const _SectionTitle('Your letters so far'),
              _Stats(
                total: store.all.length,
                longest: store.longestStreak,
                allTimeMoods: store.moodCounts(),
              ),
              const SizedBox(height: 10),
              _MoodChart(month: now, counts: store.moodCounts(year: now.year, month: now.month)),
              const SizedBox(height: 22),

              const _SectionTitle('Privacy'),
              _Card(children: [
                SwitchListTile(
                  value: s.lockEnabled,
                  onChanged: (v) => _toggleLock(context, v),
                  activeTrackColor: AppColors.accent,
                  secondary: const Icon(Icons.lock_outline, color: AppColors.ink),
                  title: Text('App lock', style: AppText.body(15, weight: FontWeight.w800)),
                  subtitle: Text(
                    'Ask for your phone PIN, fingerprint or face when opening Dear Today, '
                    'and after ${AppLock.grace.inSeconds} seconds away.',
                    style: AppText.body(12, weight: FontWeight.w500, color: AppColors.inkSoft),
                  ),
                ),
                const _Divider(),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined, color: AppColors.ink),
                  title: Text('Encryption', style: AppText.body(15, weight: FontWeight.w800)),
                  subtitle: Text(
                    'AES-256. The key lives in your phone\'s secure hardware.',
                    style: AppText.body(12, weight: FontWeight.w500, color: AppColors.inkSoft),
                  ),
                  trailing: _Pill('On', filled: true),
                ),
              ]),
              const SizedBox(height: 22),

              const _SectionTitle('Backup'),
              _Card(children: [
                _BackupNote(lastBackupAt: s.lastBackupAt),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.ink),
                  title: Text('Create a backup', style: AppText.body(15, weight: FontWeight.w800)),
                  subtitle: Text('Lock everything with a password, save it anywhere',
                      style: AppText.body(12, weight: FontWeight.w500, color: AppColors.inkSoft)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.ink),
                  onTap: () => createBackupFlow(context),
                ),
                const _Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore, color: AppColors.ink),
                  title: Text('Restore from a backup', style: AppText.body(15, weight: FontWeight.w800)),
                  subtitle: Text('Add letters from a .dtb file. Nothing here is deleted.',
                      style: AppText.body(12, weight: FontWeight.w500, color: AppColors.inkSoft)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.ink),
                  onTap: () => restoreBackupFlow(context),
                ),
              ]),
              const SizedBox(height: 22),

              const _SectionTitle('Daily reminder'),
              _Card(children: [
                SwitchListTile(
                  value: s.reminderOn,
                  onChanged: (v) => _toggleReminder(context, v),
                  activeTrackColor: AppColors.accent,
                  secondary: const Icon(Icons.notifications_none, color: AppColors.ink),
                  title: Text('Remind me to write', style: AppText.body(15, weight: FontWeight.w800)),
                  subtitle: Text('Only if I haven\'t written to today yet',
                      style: AppText.body(12, weight: FontWeight.w500, color: AppColors.inkSoft)),
                ),
                if (s.reminderOn)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Every day at',
                              style: AppText.body(13, weight: FontWeight.w700, color: AppColors.inkSoft)),
                        ),
                        OutlinedButton(
                          onPressed: () => _pickReminderTime(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink,
                            backgroundColor: AppColors.white,
                            side: const BorderSide(color: AppColors.ink, width: 1.5),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            clockTime(DateTime(2000, 1, 1, s.reminderHour, s.reminderMinute)),
                            style: AppText.hand(20),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (s.reminderOn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Wrap(
                      spacing: 4,
                      children: [
                        if (!Reminders.onTime)
                          TextButton.icon(
                            onPressed: () async {
                              await Reminders.requestOnTime();
                              await SettingsStore.instance.setReminder(on: true); // refresh this card
                            },
                            icon: const Icon(Icons.alarm_on_outlined, size: 18),
                            label: const Text('Make reminders on time'),
                          ),
                      ],
                    ),
                  ),
              ]),
              const SizedBox(height: 22),

              const _SectionTitle('Help'),
              _Card(children: [
                ListTile(
                  leading: const Icon(Icons.tour_outlined, color: AppColors.ink),
                  title: Text('Replay the tour', style: AppText.body(15, weight: FontWeight.w800)),
                  subtitle: Text('A quick look around Dear Today',
                      style: AppText.body(12, weight: FontWeight.w500, color: AppColors.inkSoft)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.ink),
                  onTap: () => SettingsStore.instance.setTourSeen(false),
                ),
              ]),
              const SizedBox(height: 26),

              const _About(),
            ],
          ),
        );
      },
    );
  }
}

/// Asks for your name. It owns its text box, so the box is only cleaned up
/// after the dialog has fully closed (not while it's still animating away).
class _NameDialog extends StatefulWidget {
  final String initial;
  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('What should we call you?', style: AppText.hand(26)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder()),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- profile

class _ProfileCard extends StatelessWidget {
  final String name;
  final String? avatarPath;
  final DateTime? since;
  final VoidCallback onEdit;
  final VoidCallback onAvatar;
  const _ProfileCard({
    required this.name,
    required this.avatarPath,
    required this.since,
    required this.onEdit,
    required this.onAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final hasName = name.isNotEmpty;
    return _Card(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Tap the stamp to change your picture.
            Semantics(
              button: true,
              label: 'Change profile picture',
              child: GestureDetector(
                onTap: onAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    StampFrame(
                      holeRadius: 2.8,
                      tilt: -4,
                      child: Container(
                        width: 58,
                        height: 70,
                        color: AppColors.peach,
                        alignment: Alignment.center,
                        child: ExcludeSemantics(
                          child: avatarPath == null
                              ? const CustomPaint(size: Size(44, 44), painter: _FacePainter())
                              : VaultImage(
                                  path: avatarPath!,
                                  decodeWidth: 300,
                                  fallback: const CustomPaint(size: Size(44, 44), painter: _FacePainter()),
                                ),
                        ),
                      ),
                    ),
                    // Little camera badge so it's clear the stamp can be tapped.
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink, width: 1.5),
                        ),
                        child: const Icon(Icons.photo_camera_outlined, size: 14, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hasName ? name : 'Hello, you',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.hand(30)),
                  const SizedBox(height: 4),
                  if (since == null)
                    Text('Your first letter is waiting', style: AppText.body(13, color: AppColors.inkSoft))
                  else ...[
                    Text('Writing to today since', style: AppText.body(13, color: AppColors.inkSoft)),
                    Text(
                      '${since!.day} ${shortMonth(since!)} ${since!.year}',
                      maxLines: 1,
                      softWrap: false,
                      style: AppText.body(13, weight: FontWeight.w800, color: AppColors.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: hasName ? 'Edit your name' : 'Add your name',
              onPressed: onEdit,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.ink, width: 1.5),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.ink),
            ),
          ],
        ),
      ),
    ]);
  }
}

/// A small smiling face with rosy cheeks, for the profile stamp.
class _FacePainter extends CustomPainter {
  const _FacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 44);
    final ink = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(22, 22), 16, Paint()..color = AppColors.white);
    canvas.drawCircle(const Offset(22, 22), 16, ink);
    final dot = Paint()..color = AppColors.ink;
    canvas.drawCircle(const Offset(16, 20), 2.2, dot);
    canvas.drawCircle(const Offset(28, 20), 2.2, dot);
    canvas.drawPath(Path()..moveTo(17, 27)..quadraticBezierTo(22, 31, 27, 27), ink);
    final blush = Paint()..color = const Color(0xFFF6B7A8);
    canvas.drawOval(Rect.fromCenter(center: const Offset(12.5, 25), width: 5.2, height: 3.2), blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(31.5, 25), width: 5.2, height: 3.2), blush);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------- stats

class _Stats extends StatelessWidget {
  final int total;
  final int longest;
  final Map<String, int> allTimeMoods;
  const _Stats({required this.total, required this.longest, required this.allTimeMoods});

  @override
  Widget build(BuildContext context) {
    final top = allTimeMoods.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mood = top.isEmpty ? null : moodFor(top.first.key);

    Widget tile({required Widget big, required String label}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                SizedBox(height: 36, child: Center(child: big)),
                const SizedBox(height: 2),
                Text(label, textAlign: TextAlign.center, style: AppText.body(12, weight: FontWeight.w700, color: AppColors.inkSoft)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        tile(big: Text('$total', style: AppText.hand(34, color: AppColors.accent)),
            label: total == 1 ? 'letter sealed' : 'letters sealed'),
        const SizedBox(width: 10),
        tile(big: Text('$longest', style: AppText.hand(34, color: AppColors.accent)),
            label: 'longest streak'),
        const SizedBox(width: 10),
        tile(
          big: Icon(mood?.icon ?? Icons.sentiment_neutral_outlined, size: 34, color: AppColors.accent),
          label: mood == null ? 'no moods yet' : 'mostly ${mood.label.toLowerCase()}',
        ),
      ],
    );
  }
}

class _MoodChart extends StatelessWidget {
  final DateTime month;
  final Map<String, int> counts;
  const _MoodChart({required this.month, required this.counts});

  // One clear pastel per mood: Down, Meh, Cosy, Happy, Excited.
  static const _tints = [
    Color(0xFFB9C2EC), // periwinkle
    Color(0xFFC9CFDB), // soft grey-blue
    Color(0xFFF3B3A3), // peach
    Color(0xFFF4D57A), // butter
    Color(0xFFA9D6B0), // mint
  ];

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    final most = counts.values.fold(0, (a, b) => a > b ? a : b);
    const maxBar = 64.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text('${monthName(month)}\'s moods', style: AppText.hand(22))),
              Text('$total ${total == 1 ? 'letter' : 'letters'}',
                  style: AppText.body(12, weight: FontWeight.w700, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: [for (final m in moods) '${m.label}: ${counts[m.key] ?? 0}'].join(', '),
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < moods.length; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Text('${counts[moods[i].key] ?? 0}',
                              style: AppText.body(11, weight: FontWeight.w800, color: AppColors.inkSoft)),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 26,
                            height: most == 0 ? 4 : 4 + (maxBar - 4) * (counts[moods[i].key] ?? 0) / most,
                            decoration: BoxDecoration(
                              color: _tints[i],
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Icon(moods[i].icon, size: 22, color: AppColors.ink),
                          Text(moods[i].label, style: AppText.body(11, weight: FontWeight.w700, color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- backup + about

class _BackupNote extends StatelessWidget {
  final DateTime? lastBackupAt;
  const _BackupNote({required this.lastBackupAt});

  @override
  Widget build(BuildContext context) {
    final last = lastBackupAt;
    final old = last == null || DateTime.now().difference(last).inDays >= 30;
    final when = last == null ? 'never' : '${last.day} ${shortMonth(last)} ${last.year}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: old ? const Color(0xFFFBF1E3) : AppColors.sage.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(old ? Icons.schedule : Icons.check_circle_outline, size: 20, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Last backup: '),
                TextSpan(text: when, style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(
                  text: old
                      ? '. A backup keeps your letters safe if this phone is lost.'
                      : '. Nicely done!',
                ),
              ]),
              style: AppText.body(12, weight: FontWeight.w600).copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Dear Today', style: AppText.hand(26)),
        const SizedBox(height: 6),
        Text('Version $appVersion · made by myokohi',
            style: AppText.body(12, weight: FontWeight.w700, color: AppColors.inkSoft)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 14, color: AppColors.inkSoft),
            const SizedBox(width: 6),
            Text('Your letters never leave this phone.',
                style: AppText.body(12, weight: FontWeight.w700, color: AppColors.inkSoft)),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- small parts

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
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.ink.withValues(alpha: 0.12)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(height: 1, indent: 16, endIndent: 16);
}

class _Pill extends StatelessWidget {
  final String text;
  final bool filled;
  const _Pill(this.text, {this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? AppColors.accent : null,
        borderRadius: BorderRadius.circular(12),
        border: filled ? null : Border.all(color: AppColors.inkSoft, width: 1.2),
      ),
      child: Text(text,
          style: AppText.body(11, weight: FontWeight.w800, color: filled ? AppColors.white : AppColors.inkSoft)),
    );
  }
}
