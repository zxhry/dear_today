import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../security/app_lock.dart';
import '../security/vault.dart';

/// Saving a plain copy to the phone's gallery (only when you ask, or when
/// "Also save to gallery" is on in Storage). Everything inside Dear Today
/// stays encrypted either way.
class Gallery {
  static const album = 'Dear Today';

  static Future<bool> _allowed() async {
    if (await Gal.hasAccess(toAlbum: true)) return true;
    return AppLock.instance.stepOutside(() => Gal.requestAccess(toAlbum: true));
  }

  /// A photo or video file that isn't encrypted yet (straight from the camera).
  static Future<bool> savePlainFile(String path, {required bool video}) async {
    try {
      if (!await _allowed()) return false;
      if (video) {
        await Gal.putVideo(path, album: album);
      } else {
        await Gal.putImage(path, album: album);
      }
      return true;
    } catch (e) {
      debugPrint('Could not save to gallery: $e');
      return false;
    }
  }

  /// Unlocks an encrypted file into a temporary copy (for sharing or the
  /// gallery). Delete it with [discard] when done.
  static Future<File> unlockedCopy(String sealedPath, String name) async {
    final temp = await getTemporaryDirectory();
    final out = File('${temp.path}/$name');
    await out.writeAsBytes(await Vault.instance.unseal(await File(sealedPath).readAsBytes()), flush: true);
    return out;
  }

  static Future<void> discard(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static Future<bool> saveStamp(Stamp s) async {
    final copy = await unlockedCopy(s.photoPath, 'stamp-${s.id}.jpg');
    try {
      return await savePlainFile(copy.path, video: false);
    } finally {
      await discard(copy);
    }
  }
}
