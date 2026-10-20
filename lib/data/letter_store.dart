import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/letter.dart';
import '../utils/dates.dart';

/// Keeps every letter, saved as a file in the app's private folder.
///
/// Version 1 is a plain JSON file. Later we'll swap this for an encrypted
/// database without the screens needing to change.
class LetterStore extends ChangeNotifier {
  LetterStore._();
  static final instance = LetterStore._();

  final List<Letter> _letters = []; // newest first
  Directory? _dir;

  List<Letter> get all => List.unmodifiable(_letters);

  List<Letter> inMonth(int year, int month) =>
      _letters.where((l) => l.date.year == year && l.date.month == month).toList();

  List<Letter> forDay(DateTime day) => _letters.where((l) => sameDay(l.date, day)).toList();

  /// "Letter No. 3" = the 3rd letter of that month, counting from the 1st.
  int numberInMonth(Letter letter) {
    final oldestFirst = inMonth(letter.date.year, letter.date.month).reversed.toList();
    final i = oldestFirst.indexWhere((l) => l.id == letter.id);
    return i < 0 ? oldestFirst.length + 1 : i + 1;
  }

  Future<Directory> _appDir() async => _dir ??= await getApplicationDocumentsDirectory();
  Future<File> _file() async => File('${(await _appDir()).path}/letters.json');
  Future<Directory> _photosDir() async {
    final d = Directory('${(await _appDir()).path}/photos');
    await d.create(recursive: true);
    return d;
  }

  Future<void> load() async {
    final file = await _file();
    if (!await file.exists()) return;
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      _letters
        ..clear()
        ..addAll(list.map((e) => Letter.fromJson(e as Map<String, dynamic>)));
      _sort();
    } catch (e) {
      // Never overwrite a diary we couldn't read: set it aside instead.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await file.rename('${file.path}.unreadable-$stamp');
      debugPrint('letters.json could not be read and was set aside: $e');
    }
    notifyListeners();
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

  Letter? _byId(String id) {
    for (final l in _letters) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Copies a newly picked photo into our private folder, so it stays even
  /// if the original is deleted from the gallery. A photo that's already
  /// ours (unchanged during an edit) is kept as it is.
  Future<String?> _keepPhoto(String id, String? path) async {
    if (path == null) return null;
    final photos = await _photosDir();
    if (path.startsWith(photos.path)) return path;
    final name = '$id-${DateTime.now().millisecondsSinceEpoch}.jpg';
    return (await File(path).copy('${photos.path}/$name')).path;
  }

  Future<void> _deleteFile(String path) async {
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
    // Write to a temporary file first, then swap it in. If the phone dies
    // mid-save, the old diary is still intact.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(_letters.map((l) => l.toJson()).toList()), flush: true);
    await tmp.rename(file.path);
  }

  static String _titleFrom(String body) {
    final words = body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(3).join(' ');
    return words.isEmpty ? 'A moment' : words;
  }
}
