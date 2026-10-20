import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Locks and unlocks bytes (letters, photos) with AES-256-GCM.
///
/// The 256-bit key is made once at random and kept in Android's Keystore
/// through flutter_secure_storage, never in the app's normal files.
/// AES-GCM also detects tampering: a changed file fails to unlock instead
/// of turning into garbage.
///
/// Big jobs (photos) run on a background isolate, so the screen keeps
/// animating smoothly while they're encrypted or decrypted.
class Vault {
  Vault._();
  static final instance = Vault._();

  static const _keyName = 'dear_today_master_key_v1';
  static const _magic = [0x44, 0x54, 0x31]; // "DT1": marks our encrypted files
  static const _backgroundAbove = 64 * 1024; // bytes; smaller jobs are quick enough here

  final _storage = FlutterSecureStorage();
  List<int>? _keyBytes;

  /// Loads the key, or creates one the very first time.
  Future<void> open() async {
    var encoded = await _storage.read(key: _keyName);
    if (encoded == null) {
      final fresh = await AesGcm.with256bits().newSecretKey();
      encoded = base64Encode(await fresh.extractBytes());
      await _storage.write(key: _keyName, value: encoded);
    }
    _keyBytes = base64Decode(encoded);
  }

  List<int> get _key => _keyBytes ?? (throw StateError('Vault.open() must run first'));

  /// Encrypts bytes. Output = "DT1" + nonce + ciphertext + tag.
  Future<Uint8List> seal(List<int> clear) =>
      clear.length < _backgroundAbove ? _sealWith(_key, clear) : _sealInBackground(_key, clear);

  /// Decrypts bytes made by [seal]. Throws if the data was changed or isn't ours.
  Future<Uint8List> unseal(List<int> data) {
    if (!isSealed(data)) throw const FormatException('Not an encrypted Dear Today file');
    return data.length < _backgroundAbove ? _unsealWith(_key, data) : _unsealInBackground(_key, data);
  }

  static bool isSealed(List<int> data) =>
      data.length > _magic.length && data[0] == _magic[0] && data[1] == _magic[1] && data[2] == _magic[2];
}

// These live outside the class so the background isolate only receives the
// bytes it needs, nothing else from the app.

Future<Uint8List> _sealInBackground(List<int> key, List<int> clear) =>
    Isolate.run(() => _sealWith(key, clear));

Future<Uint8List> _unsealInBackground(List<int> key, List<int> data) =>
    Isolate.run(() => _unsealWith(key, data));

Future<Uint8List> _sealWith(List<int> key, List<int> clear) async {
  // A new random nonce is made for every single encryption.
  final box = await AesGcm.with256bits().encrypt(clear, secretKey: SecretKey(key));
  return (BytesBuilder(copy: false)
        ..add(Vault._magic)
        ..add(box.concatenation()))
      .toBytes();
}

Future<Uint8List> _unsealWith(List<int> key, List<int> data) async {
  final aes = AesGcm.with256bits();
  final box = SecretBox.fromConcatenation(
    data.sublist(Vault._magic.length),
    nonceLength: aes.nonceLength,
    macLength: aes.macAlgorithm.macLength,
  );
  return Uint8List.fromList(await aes.decrypt(box, secretKey: SecretKey(key)));
}
