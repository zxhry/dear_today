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
  int clipSeconds = 5; // 3, 5 or 10
  DateTime? lastBackupAt;

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
      final secs = j['clipSeconds'] as int? ?? 5;
      clipSeconds = const [3, 5, 10].contains(secs) ? secs : 5;
      final b = j['lastBackupAt'] as String?;
      lastBackupAt = b == null ? null : DateTime.tryParse(b);
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
      }),
      flush: true,
    );
    await tmp.rename(f.path);
  }
}
