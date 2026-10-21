import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../security/vault.dart';
import '../theme.dart';
import '../widgets/vault_image.dart';

/// App settings (app lock, name, sign-off, colours, text size...), saved in
/// the app's private folder. Changing the look updates AppColors/AppText and
/// tells the app to redraw.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final instance = SettingsStore._();

  bool lockEnabled = false;
  String name = '';
  String signOff = 'me';
  int ink = 0;
  int paper = 0;
  int textSize = 1; // 0 Small, 1 Default, 2 Large
  DateTime? lastBackupAt;
  String? avatarPath; // your profile picture, encrypted (.dtp)
  bool reminderOn = false;
  int reminderHour = 21; // 9:00 pm
  int reminderMinute = 0;

  File? _file;
  Future<File> _settingsFile() async =>
      _file ??= File('${(await getApplicationDocumentsDirectory()).path}/settings.json');

  Future<void> load() async {
    try {
      final f = await _settingsFile();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        lockEnabled = j['lockEnabled'] as bool? ?? false;
        name = j['name'] as String? ?? '';
        signOff = j['signOff'] as String? ?? 'me';
        ink = _index(j['ink'], AppColors.inks.length);
        paper = _index(j['paper'], AppColors.papers.length);
        textSize = _index(j['textSize'], AppText.letterScales.length, fallback: 1);
        final b = j['lastBackupAt'] as String?;
        lastBackupAt = b == null ? null : DateTime.tryParse(b);
        avatarPath = j['avatarPath'] as String?;
        reminderOn = j['reminderOn'] as bool? ?? false;
        reminderHour = (j['reminderHour'] as int? ?? 21).clamp(0, 23);
        reminderMinute = (j['reminderMinute'] as int? ?? 0).clamp(0, 59);
        if (avatarPath != null && !await File(avatarPath!).exists()) avatarPath = null;
      }
    } catch (e) {
      debugPrint('settings.json could not be read: $e');
    }
    _applyLook();
  }

  static int _index(Object? v, int length, {int fallback = 0}) {
    final i = v is int ? v : fallback;
    return (i >= 0 && i < length) ? i : fallback;
  }

  void _applyLook() {
    AppColors.accent = AppColors.inks[ink].color;
    AppColors.paper = AppColors.papers[paper].color;
    AppText.letterScale = AppText.letterScales[textSize];
  }

  Future<void> setLockEnabled(bool v) => _update(() => lockEnabled = v);
  Future<void> setName(String v) => _update(() => name = v.trim());
  Future<void> setSignOff(String v) => _update(() => signOff = v.trim().isEmpty ? 'me' : v.trim());
  Future<void> setInk(int i) => _update(() => ink = i);
  Future<void> setPaper(int i) => _update(() => paper = i);
  Future<void> setTextSize(int i) => _update(() => textSize = i);
  Future<void> markBackedUp() => _update(() => lastBackupAt = DateTime.now());
  Future<void> setReminder({required bool on, int? hour, int? minute}) => _update(() {
        reminderOn = on;
        reminderHour = hour ?? reminderHour;
        reminderMinute = minute ?? reminderMinute;
      });

  /// Encrypts a picked photo as your profile picture (replacing the old one).
  Future<void> setAvatarFrom(String pickedPath) async {
    final docs = await getApplicationDocumentsDirectory();
    final picked = File(pickedPath);
    final out = File('${docs.path}/avatar-${DateTime.now().millisecondsSinceEpoch}.dtp');
    await out.writeAsBytes(await Vault.instance.seal(await picked.readAsBytes()), flush: true);

    // Don't leave a plain copy behind in the picker's temporary folder.
    final temp = await getTemporaryDirectory();
    if (pickedPath.startsWith(temp.path)) await _deleteQuietly(pickedPath);

    final old = avatarPath;
    await _update(() => avatarPath = out.path);
    if (old != null) await _deleteQuietly(old);
  }

  /// Back to the little smiley.
  Future<void> removeAvatar() async {
    final old = avatarPath;
    await _update(() => avatarPath = null);
    if (old != null) await _deleteQuietly(old);
  }

  Future<void> _deleteQuietly(String path) async {
    PhotoCache.forget(path);
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('Could not delete $path: $e');
    }
  }

  Future<void> _update(void Function() change) async {
    change();
    _applyLook();
    notifyListeners();
    final f = await _settingsFile();
    await f.writeAsString(
      jsonEncode({
        'lockEnabled': lockEnabled,
        'name': name,
        'signOff': signOff,
        'ink': ink,
        'paper': paper,
        'textSize': textSize,
        'lastBackupAt': lastBackupAt?.toIso8601String(),
        'avatarPath': avatarPath,
        'reminderOn': reminderOn,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      }),
      flush: true,
    );
  }
}
