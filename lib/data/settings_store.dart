import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// App settings, saved in the app's private folder (settings.json).
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final instance = SettingsStore._();

  ThemeMode themeMode = ThemeMode.system;
  bool lockEnabled = false;
  String vlogQuality = '720p'; // '720p' (smaller) or '1080p' (sharper)
  bool saveToGallery = false; // also keep a plain copy in the phone's gallery
  int clipSeconds = 4; // 2, 4 or 8
  DateTime? lastBackupAt;
  // How a day reel is saved.
  bool reelPortrait = false; // false 16:9, true 9:16 (for stories and Threads)
  bool reelShowTime = true; // the time in the middle of each clip
  bool reelSound = true; // keep the clips' own sound
  // "Another prompt" moves to the next question for the rest of that day.
  String promptDay = '';
  int promptSkip = 0;

  File? _file;
  Future<File> _settingsFile() async =>
      _file ??= File('${(await getApplicationDocumentsDirectory()).path}/settings.json');

  Future<void> load() async {
    try {
      final f = await _settingsFile();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      themeMode = ThemeMode.values.firstWhere((m) => m.name == j['themeMode'], orElse: () => ThemeMode.system);
      lockEnabled = j['lockEnabled'] as bool? ?? false; // kept from the letters version
      vlogQuality = j['vlogQuality'] == '1080p' ? '1080p' : '720p';
      saveToGallery = j['saveToGallery'] as bool? ?? false;
      final secs = j['clipSeconds'] as int? ?? 4;
      clipSeconds = const [2, 4, 8].contains(secs) ? secs : 4; // older 3/5/10 choices become 4
      final b = j['lastBackupAt'] as String?;
      lastBackupAt = b == null ? null : DateTime.tryParse(b);
      reelPortrait = j['reelPortrait'] as bool? ?? false;
      reelShowTime = j['reelShowTime'] as bool? ?? true;
      reelSound = j['reelSound'] as bool? ?? true;
      promptDay = j['promptDay'] as String? ?? '';
      promptSkip = j['promptSkip'] as int? ?? 0;
    } catch (e) {
      debugPrint('settings.json could not be read: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode m) => _update(() => themeMode = m);
  Future<void> setLockEnabled(bool v) => _update(() => lockEnabled = v);
  Future<void> setVlogQuality(String q) => _update(() => vlogQuality = q);
  Future<void> setSaveToGallery(bool v) => _update(() => saveToGallery = v);
  Future<void> setClipSeconds(int s) => _update(() => clipSeconds = s);
  Future<void> markBackedUp() => _update(() => lastBackupAt = DateTime.now());
  Future<void> setReelPortrait(bool v) => _update(() => reelPortrait = v);
  Future<void> setReelShowTime(bool v) => _update(() => reelShowTime = v);
  Future<void> setReelSound(bool v) => _update(() => reelSound = v);

  /// How many times "Another prompt" was tapped on [day] ("2026-11-21").
  int promptSkipOn(String day) => promptDay == day ? promptSkip : 0;
  Future<void> skipPrompt(String day) => _update(() {
        promptSkip = promptSkipOn(day) + 1;
        promptDay = day;
      });

  Future<void> _update(void Function() change) async {
    change();
    notifyListeners();
    final f = await _settingsFile();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'themeMode': themeMode.name,
        'lockEnabled': lockEnabled,
        'vlogQuality': vlogQuality,
        'saveToGallery': saveToGallery,
        'clipSeconds': clipSeconds,
        'lastBackupAt': lastBackupAt?.toIso8601String(),
        'reelPortrait': reelPortrait,
        'reelShowTime': reelShowTime,
        'reelSound': reelSound,
        'promptDay': promptDay,
        'promptSkip': promptSkip,
      }),
      flush: true,
    );
    await tmp.rename(f.path);
  }
}
