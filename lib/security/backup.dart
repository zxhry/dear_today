import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../data/letter_store.dart';
import '../data/tomorrow_store.dart';
import 'vault.dart';

/// A friendly error to show the user.
class BackupException implements Exception {
  final String message;
  BackupException(this.message);
  @override
  String toString() => message;
}

/// Password-protected backups.
///
/// File layout (.dtb):
///   "DTB1" | rounds (4 bytes) | salt (16 bytes) | AES-256-GCM(nonce + data + tag)
///
/// The key comes from YOUR password (PBKDF2-SHA256, 600,000 rounds), not
/// from this phone, so the backup can be restored on any phone.
class Backup {
  static const _magic = [0x44, 0x54, 0x42, 0x31]; // "DTB1"
  static const rounds = 600000;
  static const minPasswordLength = 8;

  static bool looksLikeBackup(List<int> data) =>
      data.length > 24 + 28 && List.generate(4, (i) => data[i]).join() == _magic.join();

  /// Builds the encrypted backup and returns the file (in the temp folder).
  static Future<File> create(String password) async {
    // 1. Gather letters and photos (photos are unlocked from the vault).
    final letters = <Map<String, dynamic>>[];
    final photos = <String, Uint8List>{};
    for (final l in LetterStore.instance.all) {
      final json = l.toJson();
      final path = l.photoPath;
      if (path != null && await File(path).exists()) {
        final name = '${l.id}.jpg';
        photos[name] = await Vault.instance.unseal(await File(path).readAsBytes());
        json['photoPath'] = name; // inside the backup, photos are referred to by name
      } else {
        json['photoPath'] = null;
      }
      letters.add(json);
    }
    final payload = _pack({
      'app': 'dear_today',
      'format': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'letters': letters,
      'tomorrow': TomorrowStore.instance.toJsonList(),
    }, photos);

    // 2. Encrypt with a key made from the password (in a background isolate,
    //    so the 600,000 rounds don't freeze the screen).
    final rng = Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));
    final sealed = await Isolate.run(() => _encrypt(payload, password, salt));

    // 3. Save it, clearing out any older backup files first.
    final temp = await getTemporaryDirectory();
    await for (final f in temp.list()) {
      if (f is File && f.path.endsWith('.dtb')) await f.delete();
    }
    final now = DateTime.now();
    final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File('${temp.path}/dear_today_backup_$stamp.dtb');
    await file.writeAsBytes(sealed, flush: true);
    return file;
  }

  /// Opens a backup and adds its letters. Returns (added, alreadyHere).
  static Future<(int, int)> restore(Uint8List data, String password) async {
    if (!looksLikeBackup(data)) {
      throw BackupException('This isn\'t a Dear Today backup file.');
    }
    final r = ByteData.sublistView(data, 4, 8).getUint32(0);
    if (r < 100000 || r > 10000000) throw BackupException('This backup file looks damaged.');
    final salt = data.sublist(8, 24);
    final body = data.sublist(24);

    final payload = await Isolate.run(() => _decrypt(body, password, salt, r));
    if (payload == null) {
      throw BackupException('Wrong password, or the backup file was changed.');
    }

    final (meta, photos) = _unpack(payload);
    if (meta['app'] != 'dear_today') throw BackupException('This isn\'t a Dear Today backup file.');
    final letters = (meta['letters'] as List).cast<Map<String, dynamic>>();
    final (added, skipped) = await LetterStore.instance.importLetters(letters, photos);
    // Letters to tomorrow come back too (older backups simply don't have any).
    final tomorrow = (meta['tomorrow'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final addedTomorrow = await TomorrowStore.instance.importFrom(tomorrow);
    return (added + addedTomorrow, skipped);
  }

  // ---- encryption (runs in a background isolate) ----

  static Future<List<int>> _deriveKey(String password, List<int> salt, int r) async {
    final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: r, bits: 256);
    final key = await kdf.deriveKeyFromPassword(password: password, nonce: salt);
    return key.extractBytes();
  }

  static Future<Uint8List> _encrypt(Uint8List payload, String password, List<int> salt) async {
    final key = SecretKey(await _deriveKey(password, salt, rounds));
    final box = await AesGcm.with256bits().encrypt(payload, secretKey: key);
    final header = ByteData(4)..setUint32(0, rounds);
    return (BytesBuilder(copy: false)
          ..add(_magic)
          ..add(header.buffer.asUint8List())
          ..add(salt)
          ..add(box.concatenation()))
        .toBytes();
  }

  /// Returns null when the password is wrong or the file was tampered with.
  static Future<Uint8List?> _decrypt(Uint8List body, String password, List<int> salt, int r) async {
    final aes = AesGcm.with256bits();
    final key = SecretKey(await _deriveKey(password, salt, r));
    try {
      final box = SecretBox.fromConcatenation(body,
          nonceLength: aes.nonceLength, macLength: aes.macAlgorithm.macLength);
      return Uint8List.fromList(await aes.decrypt(box, secretKey: key));
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  // ---- packing letters + photos into one block of bytes ----
  // [json length][json] [photo count] then for each photo: [name length][name][data length][data]

  static Uint8List _pack(Map<String, dynamic> meta, Map<String, Uint8List> photos) {
    final b = BytesBuilder(copy: false);
    void u32(int n) => b.add((ByteData(4)..setUint32(0, n)).buffer.asUint8List());
    void chunk(List<int> bytes) {
      u32(bytes.length);
      b.add(bytes);
    }

    chunk(utf8.encode(jsonEncode(meta)));
    u32(photos.length);
    photos.forEach((name, data) {
      chunk(utf8.encode(name));
      chunk(data);
    });
    return b.toBytes();
  }

  static (Map<String, dynamic>, Map<String, Uint8List>) _unpack(Uint8List data) {
    var pos = 0;
    int u32() {
      if (pos + 4 > data.length) throw BackupException('This backup file looks damaged.');
      final n = ByteData.sublistView(data, pos, pos + 4).getUint32(0);
      pos += 4;
      return n;
    }

    Uint8List chunk() {
      final n = u32();
      if (pos + n > data.length) throw BackupException('This backup file looks damaged.');
      final out = Uint8List.sublistView(data, pos, pos + n);
      pos += n;
      return out;
    }

    final meta = jsonDecode(utf8.decode(chunk())) as Map<String, dynamic>;
    final photos = <String, Uint8List>{};
    final count = u32();
    for (var i = 0; i < count; i++) {
      final name = utf8.decode(chunk());
      photos[name] = chunk();
    }
    return (meta, photos);
  }
}
