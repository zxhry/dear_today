import 'dart:io';
import 'package:flutter/material.dart';
import '../models/letter.dart';
import '../theme.dart';

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
    if (photoPath == null) return doodleView;
    return Image.file(
      File(photoPath!),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => doodleView, // photo missing? fall back to the doodle
    );
  }
}
