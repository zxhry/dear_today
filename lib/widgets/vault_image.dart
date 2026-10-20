import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../security/vault.dart';

/// Keeps recently unlocked photos in memory so scrolling the album doesn't
/// decrypt the same photo again and again. Nothing is written back to disk.
class PhotoCache {
  static final _cache = <String, Uint8List>{};
  static const _max = 40;

  static Future<Uint8List> load(String path) async {
    final hit = _cache.remove(path);
    if (hit != null) return _cache[path] = hit; // move to "most recent"
    final bytes = await Vault.instance.unseal(await File(path).readAsBytes());
    _cache[path] = bytes;
    if (_cache.length > _max) _cache.remove(_cache.keys.first);
    return bytes;
  }

  static void forget(String path) => _cache.remove(path);
}

/// Shows an encrypted photo: unlocks it in memory, never as a plain file.
class VaultImage extends StatefulWidget {
  final String path;
  final Widget fallback; // shown if the photo can't be opened
  final int? decodeWidth; // smaller = less memory for tiny stamps

  const VaultImage({super.key, required this.path, required this.fallback, this.decodeWidth});

  @override
  State<VaultImage> createState() => _VaultImageState();
}

class _VaultImageState extends State<VaultImage> {
  late Future<Uint8List> _bytes = PhotoCache.load(widget.path);

  @override
  void didUpdateWidget(VaultImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _bytes = PhotoCache.load(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snap) {
        if (snap.hasError) return widget.fallback;
        if (!snap.hasData) return Container(color: const Color(0xFFEDE7DF));
        return Image.memory(
          snap.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: widget.decodeWidth,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => widget.fallback,
        );
      },
    );
  }
}
