import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../data/journal_store.dart';
import '../models/models.dart';
import '../utils/dates.dart';
import 'gallery.dart';

/// Saves a whole day's reel to the gallery as one video: every clip, one
/// after another (in the reel's order), optionally with the time it was
/// recorded in the middle, wide (16:9) or tall (9:16), with or without sound.
/// The video is made on the phone by Android's Media3 (MainActivity.kt).
class VlogExport {
  static const _channel = MethodChannel('dear_today/video');

  /// Returns null when saved, or a message saying what went wrong.
  static Future<String?> saveDay(
    List<VlogClip> clips,
    DateTime day, {
    bool portrait = false,
    bool showTime = true,
    bool sound = true,
  }) async {
    if (clips.isEmpty) return 'There are no clips to save.';
    final temp = await getTemporaryDirectory();
    final d = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final copies = <String>[];
    final out = '${temp.path}/dear-today-vlog-$d.mp4';
    try {
      // Unlock each clip into a temporary copy, in the reel's order.
      for (final c in clips) {
        copies.add((await Gallery.unlockedCopy(c.path, 'join-${c.id}.mp4')).path);
      }
      await _channel.invokeMethod<String>('exportDay', {
        'inputs': copies,
        'times': [for (final c in clips) showTime ? clockTime(c.recordedAt) : ''],
        'output': out,
        'portrait': portrait,
        'sound': sound,
      });
      final ok = await Gallery.savePlainFile(out, video: true);
      return ok ? null : 'Couldn\'t save to the gallery.';
    } on PlatformException catch (e) {
      return 'Couldn\'t make the vlog: ${e.message}';
    } finally {
      // Remove every plain copy again.
      for (final p in [...copies, out]) {
        await JournalStore.deleteQuietly(p);
      }
    }
  }
}
