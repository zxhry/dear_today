import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../data/journal_store.dart';
import '../models/models.dart';
import 'vault.dart';

/// A friendly error to show the user.
class BackupException implements Exception {
  final String message;
  BackupException(this.message);
  @override
  String toString() => message;
}

/// Password-protected backups of stamps, diary and vlog.
///
/// File layout (.dtb):
///   "DTB2" | rounds (4 bytes) | salt (16 bytes) | record | record | ...
///   each record = length (4 bytes) + AES-256-GCM(nonce + data + tag)
///
/// The first record is the list of everything (JSON); then one record per
/// photo or clip, in the order the list names them. Writing one record at a
/// time means a big vlog never has to fit in memory all at once.
///
/// The key comes from YOUR password (PBKDF2-SHA256, 600,000 rounds), not
/// from this phone, so the backup can be restored on any phone.
class Backup {
  static const _magic = [0x44, 0x54, 0x42, 0x32]; // "DTB2"
  static const _oldMagic = [0x44, 0x54, 0x42, 0x31]; // "DTB1": letters version
  static const rounds = 600000;
  static const minPasswordLength = 8;

  static bool _starts(List<int> data, List<int> magic) =>
      data.length >= 4 && List.generate(4, (i) => data[i] == magic[i]).every((ok) => ok);

  /// Builds the encrypted backup and returns the file (in the temp folder).
  static Future<File> create(String password) async {
    final store = JournalStore.instance;

    // 1. Give every photo and clip a short name inside the backup.
    final media = <String, String>{}; // name in backup -> encrypted file on this phone
    String nameFor(String path, String ext) {
      final name = '${media.length}.$ext';
      media[name] = path;
      return name;
    }

    final stamps = [
      for (final s in store.stamps) {...s.toJson(), 'photoPath': nameFor(s.photoPath, 'jpg')},
    ];
    final entries = [
      for (final e in store.entries) {...e.toJson(), 'photos': [for (final p in e.photos) nameFor(p, 'jpg')]},
    ];
    final clips = [
      for (final c in store.clips) {...c.toJson(), 'path': nameFor(c.path, 'mp4')},
    ];
    final meta = {
      'app': 'dear_today',
      'format': 2,
      'createdAt': DateTime.now().toIso8601String(),
      'stamps': stamps,
      'sets': store.sets.map((s) => s.toJson()).toList(),
      'entries': entries,
      'clips': clips,
      'media': media.keys.toList(),
    };

    // 2. A key made from the password (in a background isolate, so the
    //    600,000 rounds don't freeze the screen).
    final rng = Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));
    final key = await _deriveKeyInBackground(password, salt, rounds);

    // 3. Write the file one record at a time.
    final temp = await getTemporaryDirectory();
    await for (final f in temp.list()) {
      if (f is File && f.path.endsWith('.dtb')) await f.delete();
    }
    final now = DateTime.now();
    final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File('${temp.path}/dear_today_backup_$stamp.dtb');
    final out = file.openWrite();
    try {
      out.add(_magic);
      out.add(_u32(rounds));
      out.add(salt);
      Future<void> record(List<int> clear) async {
        final sealed = await _encrypt(key, clear);
        out.add(_u32(sealed.length));
        out.add(sealed);
      }

      await record(utf8.encode(jsonEncode(meta)));
      for (final path in media.values) {
        final f = File(path);
        // A missing file is saved as an empty record, so the order still lines up.
        final clear = await f.exists() ? await Vault.instance.unseal(await f.readAsBytes()) : Uint8List(0);
        await record(clear);
      }
      await out.flush();
    } finally {
      await out.close();
    }
    return file;
  }

  /// Opens a backup file and adds what's in it. Returns how many items were added.
  static Future<int> restore(File file, String password) async {
    final raf = await file.open();
    try {
      final header = await raf.read(24);
      if (_starts(header, _oldMagic)) {
        throw BackupException('This backup is from the old letters version of Dear Today, so it can\'t be opened here.');
      }
      if (header.length < 24 || !_starts(header, _magic)) {
        throw BackupException('This isn\'t a Dear Today backup file.');
      }
      final r = ByteData.sublistView(header, 4, 8).getUint32(0);
      if (r < 100000 || r > 10000000) throw BackupException('This backup file looks damaged.');
      final salt = header.sublist(8, 24);
      final key = await _deriveKeyInBackground(password, salt, r);

      Future<Uint8List> next() async {
        final len = await raf.read(4);
        if (len.length < 4) throw BackupException('This backup file looks damaged.');
        final n = ByteData.sublistView(len).getUint32(0);
        final body = await raf.read(n);
        if (body.length < n) throw BackupException('This backup file looks damaged.');
        final clear = await _decrypt(key, body);
        if (clear == null) throw BackupException('Wrong password, or the backup file was changed.');
        return clear;
      }

      final meta = jsonDecode(utf8.decode(await next())) as Map<String, dynamic>;
      if (meta['app'] != 'dear_today') throw BackupException('This isn\'t a Dear Today backup file.');

      // Re-encrypt each photo and clip for this phone, skipping ones we already have.
      final store = JournalStore.instance;
      List<Map<String, dynamic>> list(String k) => (meta[k] as List? ?? const []).cast<Map<String, dynamic>>();
      final wanted = <String>{};
      for (final s in list('stamps')) {
        if (!store.hasId(s['id'] as String)) wanted.add(s['photoPath'] as String);
      }
      for (final e in list('entries')) {
        if (!store.hasId(e['id'] as String)) wanted.addAll((e['photos'] as List).cast<String>());
      }
      for (final c in list('clips')) {
        if (!store.hasId(c['id'] as String)) wanted.add(c['path'] as String);
      }

      final paths = <String, String>{}; // name in backup -> new encrypted file here
      for (final name in (meta['media'] as List? ?? const []).cast<String>()) {
        final data = await next();
        if (!wanted.contains(name) || data.isEmpty) continue;
        paths[name] = await store.sealBytes(data, name.endsWith('.mp4') ? 'dtv' : 'dtp');
      }

      final stamps = <Stamp>[];
      for (final s in list('stamps')) {
        final p = paths[s['photoPath']];
        if (p != null) stamps.add(Stamp.fromJson({...s, 'photoPath': p}));
      }
      final entries = [
        for (final e in list('entries'))
          if (!store.hasId(e['id'] as String))
            DiaryEntry.fromJson({
              ...e,
              'photos': [
                for (final n in (e['photos'] as List).cast<String>())
                  if (paths[n] != null) paths[n]!,
              ],
            }),
      ];
      final clips = <VlogClip>[];
      for (final c in list('clips')) {
        final p = paths[c['path']];
        if (p != null) clips.add(VlogClip.fromJson({...c, 'path': p}));
      }
      return await store.importAll(
        stamps: stamps,
        sets: list('sets').map(StampSet.fromJson).toList(),
        entries: entries,
        clips: clips,
      );
    } finally {
      await raf.close();
    }
  }

  // ---- encryption ----

  static Uint8List _u32(int n) => (ByteData(4)..setUint32(0, n)).buffer.asUint8List();

  /// Runs [_deriveKey] in a background isolate. Kept as its own function on
  /// purpose: a closure passed to Isolate.run captures its surrounding scope,
  /// and in restore() that scope holds an open file, which can't be sent to
  /// another isolate. Here the closure can only see these three arguments.
  static Future<List<int>> _deriveKeyInBackground(String password, List<int> salt, int r) =>
      Isolate.run(() => _deriveKey(password, salt, r));

  static Future<List<int>> _deriveKey(String password, List<int> salt, int r) async {
    final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: r, bits: 256);
    final key = await kdf.deriveKeyFromPassword(password: password, nonce: salt);
    return key.extractBytes();
  }

  // Big records (photos, clips) are encrypted on a background isolate.
  static Future<Uint8List> _encrypt(List<int> key, List<int> clear) =>
      clear.length < 64 * 1024 ? _encryptWith(key, clear) : Isolate.run(() => _encryptWith(key, clear));

  static Future<Uint8List?> _decrypt(List<int> key, Uint8List body) =>
      body.length < 64 * 1024 ? _decryptWith(key, body) : Isolate.run(() => _decryptWith(key, body));

  static Future<Uint8List> _encryptWith(List<int> key, List<int> clear) async {
    final box = await AesGcm.with256bits().encrypt(clear, secretKey: SecretKey(key));
    return Uint8List.fromList(box.concatenation());
  }

  /// Returns null when the password is wrong or the file was tampered with.
  static Future<Uint8List?> _decryptWith(List<int> key, Uint8List body) async {
    final aes = AesGcm.with256bits();
    try {
      final box = SecretBox.fromConcatenation(body,
          nonceLength: aes.nonceLength, macLength: aes.macAlgorithm.macLength);
      return Uint8List.fromList(await aes.decrypt(box, secretKey: SecretKey(key)));
    } on SecretBoxAuthenticationError {
      return null;
    }
  }
}
