import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Locks and unlocks bytes (letters, photos) with AES-256-GCM.
///
/// The 256-bit key is made once at random and kept in Android's Keystore
/// through flutter_secure_storage, never in the app's normal files.
/// AES-GCM also detects tampering: a changed file fails to unlock instead
/// of turning into garbage.
class Vault {
  Vault._();
  static final instance = Vault._();

  static const _keyName = 'dear_today_master_key_v1';
  static const _magic = [0x44, 0x54, 0x31]; // "DT1": marks our encrypted files

  final _aes = AesGcm.with256bits();
  final _storage = FlutterSecureStorage();
  SecretKey? _key;

  /// Loads the key, or creates one the very first time.
  Future<void> open() async {
    var encoded = await _storage.read(key: _keyName);
    if (encoded == null) {
      final fresh = await _aes.newSecretKey();
      encoded = base64Encode(await fresh.extractBytes());
      await _storage.write(key: _keyName, value: encoded);
    }
    _key = SecretKey(base64Decode(encoded));
  }

  SecretKey get _secret => _key ?? (throw StateError('Vault.open() must run first'));

  /// Encrypts bytes. Output = "DT1" + nonce + ciphertext + tag.
  Future<Uint8List> seal(List<int> clear) async {
    // A new random nonce is made for every single encryption.
    final box = await _aes.encrypt(clear, secretKey: _secret);
    return (BytesBuilder(copy: false)
          ..add(_magic)
          ..add(box.concatenation()))
        .toBytes();
  }

  /// Decrypts bytes made by [seal]. Throws if the data was changed or isn't ours.
  Future<Uint8List> unseal(List<int> data) async {
    if (!isSealed(data)) throw const FormatException('Not an encrypted Dear Today file');
    final box = SecretBox.fromConcatenation(
      data.sublist(_magic.length),
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    return Uint8List.fromList(await _aes.decrypt(box, secretKey: _secret));
  }

  static bool isSealed(List<int> data) =>
      data.length > _magic.length && data[0] == _magic[0] && data[1] == _magic[1] && data[2] == _magic[2];
}
