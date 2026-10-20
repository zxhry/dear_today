import 'dart:io';
import 'package:flutter/material.dart';
import '../models/letter.dart';
import '../theme.dart';
import 'vault_image.dart';

/// The picture inside a stamp: the photo if there is one, otherwise the doodle.
class StampPicture extends StatelessWidget {
  final String? photoPath;
  final String doodle;
  final double iconSize;

  const StampPicture({super.key, this.photoPath, required this.doodle, this.iconSize = 32});

  @override
  Widget build(BuildContext context) {
    final d = doodleFor(doodle);
    final doodleView = Container(
      color: d.tint,
      alignment: Alignment.center,
      child: Icon(d.icon, size: iconSize, color: AppColors.ink),
    );
    final path = photoPath;
    if (path == null) return doodleView;

    // Saved letters' photos are encrypted (.dtp); a just-picked photo is a
    // normal temporary file until the letter is sealed.
    if (path.endsWith('.dtp')) {
      return VaultImage(path: path, fallback: doodleView, decodeWidth: iconSize < 40 ? 300 : 1000);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => doodleView,
    );
  }
}
