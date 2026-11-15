import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../security/vault.dart';
import '../utils/dates.dart';
import '../widgets/vault_image.dart';

/// How much space each part of the app uses on the phone.
class StorageUsage {
  final int stampBytes, diaryBytes, vlogBytes;
  final int stampCount, diaryPhotoCount, clipCount;

  const StorageUsage({
    required this.stampBytes,
    required this.diaryBytes,
    required this.vlogBytes,
    required this.stampCount,
    required this.diaryPhotoCount,
    required this.clipCount,
  });

  int get total => stampBytes + diaryBytes + vlogBytes;
}

/// Keeps stamps, sets, diary entries and vlog clips in the app's private
/// folder, all encrypted.
///
/// journal.dt   = the list of everything, as JSON, encrypted with the Vault
/// media/*.dtp  = photos (stamps and diary), encrypted
/// media/*.dtv  = vlog clips, encrypted
class JournalStore extends ChangeNotifier {
  JournalStore._();
  static final instance = JournalStore._();

  final List<Stamp> _stamps = []; // newest first
  final List<StampSet> _sets = []; // oldest first
  final List<DiaryEntry> _entries = []; // newest first
  final List<VlogClip> _clips = []; // oldest first
  Directory? _dir;

  List<Stamp> get stamps => List.unmodifiable(_stamps);
  List<StampSet> get sets => List.unmodifiable(_sets);
  List<DiaryEntry> get entries => List.unmodifiable(_entries);
  List<VlogClip> get clips => List.unmodifiable(_clips);

  // ---------- files ----------

  Future<Directory> _appDir() async => _dir ??= await getApplicationDocumentsDirectory();
  Future<File> _file() async => File('${(await _appDir()).path}/journal.dt');

  Future<Directory> mediaDir() async {
    final d = Directory('${(await _appDir()).path}/media');
    await d.create(recursive: true);
    return d;
  }

  /// Clips are unlocked here only while they're being played.
  Future<Directory> _playbackDir() async {
    final d = Directory('${(await getTemporaryDirectory()).path}/playback');
    await d.create(recursive: true);
    return d;
  }

  Future<void> load() async {
    final file = await _file();
    try {
      if (await file.exists()) {
        final clear = await Vault.instance.unseal(await file.readAsBytes());
        final j = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
        List<Map<String, dynamic>> list(String key) => (j[key] as List? ?? const []).cast<Map<String, dynamic>>();
        _stamps
          ..clear()
          ..addAll(list('stamps').map(Stamp.fromJson));
        _sets
          ..clear()
          ..addAll(list('sets').map(StampSet.fromJson));
        _entries
          ..clear()
          ..addAll(list('entries').map(DiaryEntry.fromJson));
        _clips
          ..clear()
          ..addAll(list('clips').map(VlogClip.fromJson));
        _sort();
      }
    } catch (e) {
      // Never overwrite a journal we couldn't read: set it aside instead.
      if (await file.exists()) {
        await file.rename('${file.path}.unreadable-${DateTime.now().millisecondsSinceEpoch}');
      }
      _stamps.clear();
      _sets.clear();
      _entries.clear();
      _clips.clear();
      debugPrint('Journal could not be read and was set aside: $e');
    }
    await clearPlayback();
    notifyListeners();
  }

  void _sort() {
    _stamps.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    _sets.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _entries.sort((a, b) => b.at.compareTo(a.at));
    _clips.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }

  Future<void> _save() async {
    final file = await _file();
    final json = jsonEncode({
      'format': 2,
      'stamps': _stamps.map((s) => s.toJson()).toList(),
      'sets': _sets.map((s) => s.toJson()).toList(),
      'entries': _entries.map((e) => e.toJson()).toList(),
      'clips': _clips.map((c) => c.toJson()).toList(),
    });
    final sealed = await Vault.instance.seal(utf8.encode(json));
    // Write to a temporary file first, then swap it in. If the phone dies
    // mid-save, the old journal is still intact.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(sealed, flush: true);
    await tmp.rename(file.path);
  }

  Future<void> _changed() async {
    _sort();
    await _save();
    notifyListeners();
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Encrypts a file (a photo or clip from the camera) into the media folder.
  /// The plain original is removed when [deleteSource] is true.
  Future<String> _sealFile(String source, String ext, {bool deleteSource = true}) async {
    final dir = await mediaDir();
    final out = File('${dir.path}/${_newId()}.$ext');
    await out.writeAsBytes(await Vault.instance.seal(await File(source).readAsBytes()), flush: true);
    // Only ever removes the camera's or picker's temporary copy, never a
    // file in your gallery.
    if (deleteSource && source.startsWith((await getTemporaryDirectory()).path)) {
      await deleteQuietly(source);
    }
    return out.path;
  }

  /// Encrypts bytes (from a backup) into the media folder.
  Future<String> sealBytes(Uint8List bytes, String ext) async {
    final dir = await mediaDir();
    final out = File('${dir.path}/${_newId()}.$ext');
    await out.writeAsBytes(await Vault.instance.seal(bytes), flush: true);
    return out.path;
  }

  static Future<void> deleteQuietly(String path) async {
    PhotoCache.forget(path);
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('Could not delete $path: $e');
    }
  }

  // ---------- stamps ----------

  List<Stamp> stampsInMonth(DateTime month) => _stamps.where((s) => sameMonth(s.takenAt, month)).toList();
  List<Stamp> stampsInSet(String setId) => _stamps.where((s) => s.setId == setId).toList();

  /// Months that have stamps, newest first.
  List<DateTime> get stampMonths {
    final months = _stamps.map((s) => monthOnly(s.takenAt)).toSet().toList();
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  /// "No. 3" = the 3rd stamp of that month.
  int numberInMonth(Stamp stamp) {
    final oldestFirst = stampsInMonth(stamp.takenAt).reversed.toList();
    final i = oldestFirst.indexWhere((s) => s.id == stamp.id);
    return i < 0 ? oldestFirst.length + 1 : i + 1;
  }

  StampSet? setById(String? id) {
    if (id == null) return null;
    for (final s in _sets) {
      if (s.id == id) return s;
    }
    return null;
  }

  Stamp? stampById(String id) {
    for (final s in _stamps) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<Stamp> addStamp({
    required String photo,
    required StampShape shape,
    String title = '',
    String place = '',
    String? setId,
    DateTime? takenAt,
    bool deleteSource = true,
  }) async {
    final stamp = Stamp(
      id: _newId(),
      takenAt: takenAt ?? DateTime.now(),
      title: title.trim(),
      place: place.trim(),
      setId: setId,
      photoPath: await _sealFile(photo, 'dtp', deleteSource: deleteSource),
      shape: shape,
    );
    _stamps.add(stamp);
    await _changed();
    return stamp;
  }

  Future<void> updateStamp(Stamp stamp) async {
    final i = _stamps.indexWhere((s) => s.id == stamp.id);
    if (i < 0) return;
    _stamps[i] = stamp;
    await _changed();
  }

  Future<void> deleteStamp(Stamp stamp) async {
    _stamps.removeWhere((s) => s.id == stamp.id);
    await deleteQuietly(stamp.photoPath);
    await _changed();
  }

  Future<StampSet> addSet(String name) async {
    final set = StampSet(id: _newId(), name: name.trim(), createdAt: DateTime.now());
    _sets.add(set);
    await _changed();
    return set;
  }

  Future<void> renameSet(StampSet set, String name) async {
    final i = _sets.indexWhere((s) => s.id == set.id);
    if (i < 0) return;
    _sets[i] = set.renamed(name.trim());
    await _changed();
  }

  /// Removes the set. Its stamps stay on their monthly sheets.
  Future<void> deleteSet(StampSet set) async {
    _sets.removeWhere((s) => s.id == set.id);
    for (var i = 0; i < _stamps.length; i++) {
      if (_stamps[i].setId == set.id) _stamps[i] = _stamps[i].copyWith(clearSet: true);
    }
    await _changed();
  }

  // ---------- diary ----------

  /// Every diary photo with the entry it belongs to, newest first.
  List<(DiaryEntry, String)> get diaryPhotos => [
        for (final e in _entries)
          for (final p in e.photos) (e, p),
      ];

  /// Saves a new entry, or changes to an existing one.
  /// [keptPhotos] are the entry's photos still wanted; [newPhotos] are
  /// freshly picked files to encrypt and add.
  Future<DiaryEntry> saveEntry({
    DiaryEntry? editing,
    required String text,
    List<String> keptPhotos = const [],
    List<String> newPhotos = const [],
  }) async {
    final sealed = <String>[for (final p in newPhotos) await _sealFile(p, 'dtp')];
    final photos = [...keptPhotos, ...sealed];
    final DiaryEntry entry;
    if (editing != null) {
      for (final old in editing.photos) {
        if (!keptPhotos.contains(old)) await deleteQuietly(old);
      }
      entry = editing.copyWith(text: text.trim(), photos: photos);
      _entries.removeWhere((e) => e.id == editing.id);
    } else {
      entry = DiaryEntry(id: _newId(), at: DateTime.now(), text: text.trim(), photos: photos);
    }
    _entries.add(entry);
    await _changed();
    return entry;
  }

  Future<void> deleteEntry(DiaryEntry entry) async {
    _entries.removeWhere((e) => e.id == entry.id);
    for (final p in entry.photos) {
      await deleteQuietly(p);
    }
    await _changed();
  }

  // ---------- vlog ----------

  List<VlogClip> clipsOn(DateTime day) => _clips.where((c) => sameDay(c.recordedAt, day)).toList();

  /// Days that have clips, newest first.
  List<DateTime> get clipDays {
    final days = _clips.map((c) => dayOnly(c.recordedAt)).toSet().toList();
    days.sort((a, b) => b.compareTo(a));
    return days;
  }

  Future<VlogClip> addClip({
    required String video,
    required DateTime recordedAt,
    required int durationMs,
    required String quality,
  }) async {
    final clip = VlogClip(
      id: _newId(),
      recordedAt: recordedAt,
      durationMs: durationMs,
      path: await _sealFile(video, 'dtv'),
      quality: quality,
    );
    _clips.add(clip);
    await _changed();
    return clip;
  }

  Future<void> deleteClip(VlogClip clip) => removeClips([clip]);

  /// Removes clips from the phone. Returns how many bytes that freed.
  Future<int> removeClips(List<VlogClip> clips) async {
    final freed = await sizeOf(clips.map((c) => c.path));
    final ids = clips.map((c) => c.id).toSet();
    _clips.removeWhere((c) => ids.contains(c.id));
    for (final c in clips) {
      await deleteQuietly(c.path);
    }
    await _changed();
    return freed;
  }

  List<VlogClip> clipsOlderThan(DateTime cutoff) => _clips.where((c) => c.recordedAt.isBefore(cutoff)).toList();

  /// Unlocks a clip into the app's temporary folder so the video player can
  /// read it. [clearPlayback] removes these copies again.
  Future<File> openClip(VlogClip clip) async {
    final out = File('${(await _playbackDir()).path}/${clip.id}.mp4');
    if (await out.exists()) return out;
    final clear = await Vault.instance.unseal(await File(clip.path).readAsBytes());
    await out.writeAsBytes(clear, flush: true);
    return out;
  }

  Future<void> clearPlayback() async {
    try {
      final d = await _playbackDir();
      await for (final f in d.list()) {
        if (f is File) await f.delete();
      }
    } catch (e) {
      debugPrint('Could not clear playback copies: $e');
    }
  }

  // ---------- storage ----------

  static Future<int> sizeOf(Iterable<String> paths) async {
    var total = 0;
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) total += await f.length();
      } catch (_) {}
    }
    return total;
  }

  Future<StorageUsage> usage() async {
    final diary = diaryPhotos.map((e) => e.$2).toList();
    return StorageUsage(
      stampBytes: await sizeOf(_stamps.map((s) => s.photoPath)),
      diaryBytes: await sizeOf(diary),
      vlogBytes: await sizeOf(_clips.map((c) => c.path)),
      stampCount: _stamps.length,
      diaryPhotoCount: diary.length,
      clipCount: _clips.length,
    );
  }

  // ---------- backups ----------

  bool hasId(String id) =>
      _stamps.any((s) => s.id == id) ||
      _sets.any((s) => s.id == id) ||
      _entries.any((e) => e.id == id) ||
      _clips.any((c) => c.id == id);

  /// Adds things restored from a backup (their media already re-encrypted
  /// for this phone). Anything already here is skipped, so restoring never
  /// deletes or duplicates. Returns how many items were added.
  Future<int> importAll({
    required List<Stamp> stamps,
    required List<StampSet> sets,
    required List<DiaryEntry> entries,
    required List<VlogClip> clips,
  }) async {
    var added = 0;
    for (final s in sets) {
      if (_sets.any((x) => x.id == s.id)) continue;
      _sets.add(s);
      added++;
    }
    for (final s in stamps) {
      if (_stamps.any((x) => x.id == s.id)) continue;
      _stamps.add(s);
      added++;
    }
    for (final e in entries) {
      if (_entries.any((x) => x.id == e.id)) continue;
      _entries.add(e);
      added++;
    }
    for (final c in clips) {
      if (_clips.any((x) => x.id == c.id)) continue;
      _clips.add(c);
      added++;
    }
    if (added > 0) await _changed();
    return added;
  }
}
