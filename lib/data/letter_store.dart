import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/letter.dart';
import '../security/vault.dart';
import '../utils/dates.dart';
import '../widgets/vault_image.dart';

/// Keeps every letter in the app's private folder, encrypted.
///
/// letters.dt  = all letters as JSON, encrypted with the Vault
/// photos/*.dtp = each photo, encrypted with the Vault
class LetterStore extends ChangeNotifier {
  LetterStore._();
  static final instance = LetterStore._();

  final List<Letter> _letters = []; // newest first
  Directory? _dir;

  List<Letter> get all => List.unmodifiable(_letters);

  List<Letter> inMonth(int year, int month) =>
      _letters.where((l) => l.date.year == year && l.date.month == month).toList();

  List<Letter> forDay(DateTime day) => _letters.where((l) => sameDay(l.date, day)).toList();

  /// How many days in a row have a letter, ending today (or yesterday,
  /// so the streak doesn't vanish in the morning before you've written).
  int get streak {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (forDay(day).isEmpty) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (forDay(day).isNotEmpty) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// The day of your very first letter (null before you've written any).
  DateTime? get firstLetterDate => _letters.isEmpty ? null : _letters.last.date;

  /// The most days in a row you've ever written.
  int get longestStreak {
    final days = _letters.map((l) => dayOnly(l.date)).toSet().toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      run = (prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  /// How many letters had each mood, in one month (or all time if null).
  Map<String, int> moodCounts({int? year, int? month}) {
    final counts = {for (final m in moods) m.key: 0};
    for (final l in _letters) {
      if (year != null && (l.date.year != year || l.date.month != month)) continue;
      counts[l.mood] = (counts[l.mood] ?? 0) + 1;
    }
    return counts;
  }

  /// "Letter No. 3" = the 3rd letter of that month, counting from the 1st.
  int numberInMonth(Letter letter) {
    final oldestFirst = inMonth(letter.date.year, letter.date.month).reversed.toList();
    final i = oldestFirst.indexWhere((l) => l.id == letter.id);
    return i < 0 ? oldestFirst.length + 1 : i + 1;
  }

  Future<Directory> _appDir() async => _dir ??= await getApplicationDocumentsDirectory();
  Future<File> _file() async => File('${(await _appDir()).path}/letters.dt');
  Future<File> _legacyFile() async => File('${(await _appDir()).path}/letters.json'); // before encryption
  Future<Directory> _photosDir() async {
    final d = Directory('${(await _appDir()).path}/photos');
    await d.create(recursive: true);
    return d;
  }

  Future<void> load() async {
    final file = await _file();
    final legacy = await _legacyFile();
    try {
      if (await file.exists()) {
        final clear = await Vault.instance.unseal(await file.readAsBytes());
        _fill(jsonDecode(utf8.decode(clear)) as List);
      } else if (await legacy.exists()) {
        // One-time upgrade: encrypt letters and photos saved before encryption existed.
        _fill(jsonDecode(await legacy.readAsString()) as List);
        await _encryptOldPhotos();
        await _save();
        await legacy.delete();
        debugPrint('Upgraded ${_letters.length} letters to encrypted storage.');
      }
    } catch (e) {
      // Never overwrite a diary we couldn't read: set it aside instead.
      final broken = await file.exists() ? file : legacy;
      if (await broken.exists()) {
        await broken.rename('${broken.path}.unreadable-${DateTime.now().millisecondsSinceEpoch}');
      }
      _letters.clear();
      debugPrint('Letters could not be read and were set aside: $e');
    }
    notifyListeners();
  }

  void _fill(List list) {
    _letters
      ..clear()
      ..addAll(list.map((e) => Letter.fromJson(e as Map<String, dynamic>)));
    _sort();
  }

  Future<void> _encryptOldPhotos() async {
    for (var i = 0; i < _letters.length; i++) {
      final path = _letters[i].photoPath;
      if (path == null || path.endsWith('.dtp')) continue;
      final old = File(path);
      if (!await old.exists()) {
        _letters[i] = _letters[i].withPhoto(null);
        continue;
      }
      final sealed = await _sealPhotoFile(_letters[i].id, old);
      await old.delete();
      _letters[i] = _letters[i].withPhoto(sealed);
    }
  }

  /// Seals a new letter, or saves changes when the draft is an edit.
  Future<Letter> seal(LetterDraft draft) async {
    final old = draft.isEditing ? _byId(draft.editingId!) : null;
    final id = old?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final photo = await _keepPhoto(id, draft.photoPath);

    final letter = Letter(
      id: id,
      date: dayOnly(draft.date),
      sealedAt: old?.sealedAt ?? DateTime.now(),
      title: draft.title.trim().isEmpty ? _titleFrom(draft.body) : draft.title.trim(),
      body: draft.body.trim(),
      mood: draft.mood,
      doodle: draft.doodle,
      photoPath: photo,
    );

    if (old != null) {
      _letters.removeWhere((l) => l.id == old.id);
      if (old.photoPath != null && old.photoPath != photo) await _deleteFile(old.photoPath!);
    }
    _letters.add(letter);
    _sort();
    await _save();
    notifyListeners();
    return letter;
  }

  /// Removes a letter and its photo for good.
  Future<void> delete(Letter letter) async {
    _letters.removeWhere((l) => l.id == letter.id);
    if (letter.photoPath != null) await _deleteFile(letter.photoPath!);
    await _save();
    notifyListeners();
  }

  /// Adds letters from a backup. Letters already here are skipped, so
  /// restoring never deletes or duplicates anything. Returns (added, skipped).
  Future<(int, int)> importLetters(List<Map<String, dynamic>> entries, Map<String, Uint8List> photos) async {
    var added = 0, skipped = 0;
    for (final json in entries) {
      final photoName = json['photoPath'] as String?;
      var letter = Letter.fromJson({...json, 'photoPath': null});
      if (_byId(letter.id) != null) {
        skipped++;
        continue;
      }
      final photo = photoName == null ? null : photos[photoName];
      if (photo != null) {
        final dir = await _photosDir();
        final out = File('${dir.path}/${letter.id}-${DateTime.now().millisecondsSinceEpoch}.dtp');
        await out.writeAsBytes(await Vault.instance.seal(photo), flush: true);
        letter = letter.withPhoto(out.path);
      }
      _letters.add(letter);
      added++;
    }
    if (added > 0) {
      _sort();
      await _save();
      notifyListeners();
    }
    return (added, skipped);
  }

  Letter? _byId(String id) {
    for (final l in _letters) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Encrypts a newly picked photo into our private folder. A photo that's
  /// already ours (unchanged during an edit) is kept as it is.
  Future<String?> _keepPhoto(String id, String? path) async {
    if (path == null) return null;
    final photos = await _photosDir();
    if (path.startsWith(photos.path)) return path;

    final picked = File(path);
    final sealed = await _sealPhotoFile(id, picked);

    // The picker left a plain copy in the app's temporary folder; remove it
    // so no unencrypted version stays behind. (Never touches your gallery.)
    final temp = await getTemporaryDirectory();
    if (path.startsWith(temp.path)) await _deleteFile(path);
    return sealed;
  }

  Future<String> _sealPhotoFile(String id, File source) async {
    final photos = await _photosDir();
    final out = File('${photos.path}/$id-${DateTime.now().millisecondsSinceEpoch}.dtp');
    await out.writeAsBytes(await Vault.instance.seal(await source.readAsBytes()), flush: true);
    return out.path;
  }

  Future<void> _deleteFile(String path) async {
    PhotoCache.forget(path);
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('Could not delete $path: $e');
    }
  }

  // Newest day first; within one day, the most recently sealed first.
  void _sort() => _letters.sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.sealedAt.compareTo(a.sealedAt);
      });

  Future<void> _save() async {
    final file = await _file();
    final json = jsonEncode(_letters.map((l) => l.toJson()).toList());
    final sealed = await Vault.instance.seal(utf8.encode(json));
    // Write to a temporary file first, then swap it in. If the phone dies
    // mid-save, the old diary is still intact.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(sealed, flush: true);
    await tmp.rename(file.path);
  }

  static String _titleFrom(String body) {
    final words = body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(3).join(' ');
    return words.isEmpty ? 'A moment' : words;
  }
}
