import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Small app settings (like whether the app lock is on), saved in the
/// app's private folder.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final instance = SettingsStore._();

  bool _lockEnabled = false;
  bool get lockEnabled => _lockEnabled;

  File? _file;
  Future<File> _settingsFile() async =>
      _file ??= File('${(await getApplicationDocumentsDirectory()).path}/settings.json');

  Future<void> load() async {
    try {
      final f = await _settingsFile();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _lockEnabled = j['lockEnabled'] as bool? ?? false;
    } catch (e) {
      debugPrint('settings.json could not be read: $e');
    }
  }

  Future<void> setLockEnabled(bool value) async {
    _lockEnabled = value;
    final f = await _settingsFile();
    await f.writeAsString(jsonEncode({'lockEnabled': _lockEnabled}), flush: true);
    notifyListeners();
  }
}
