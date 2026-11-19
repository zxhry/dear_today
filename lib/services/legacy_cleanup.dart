import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Removes what the old letters version of Dear Today left in the app's
/// private folder (letters, their photos, letters to tomorrow and the
/// profile picture). v2 started fresh and never reads them.
///
/// Only these exact old names are touched; v2's own files (journal.dt,
/// media/, settings.json) are never affected. Safe to run on every start:
/// once the old files are gone it does nothing.
class LegacyCleanup {
  static Future<void> run() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final oldFiles = RegExp(r'^(letters\.(dt|json)|tomorrow\.dt|avatar-\d+\.dtp)(\.tmp|\.unreadable-\d+)?$');
      await for (final e in docs.list()) {
        final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (e is File && oldFiles.hasMatch(name)) {
          await e.delete();
        } else if (e is Directory && name == 'photos') {
          await e.delete(recursive: true); // the old letters' encrypted photos
        }
      }
    } catch (e) {
      debugPrint('Old letters data could not be cleared: $e');
    }
  }
}
