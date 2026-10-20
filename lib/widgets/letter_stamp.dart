import 'package:flutter/material.dart';
import '../models/letter.dart';
import '../theme.dart';
import 'stamp.dart';

/// One small stamp in the album grid: picture area, short title, day number.
class LetterStamp extends StatelessWidget {
  final Letter letter;
  final double tilt;
  final VoidCallback? onTap;

  const LetterStamp({super.key, required this.letter, this.tilt = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${letter.title}, ${letter.date.day} October',
      child: GestureDetector(
        onTap: onTap,
        child: StampFrame(
          tilt: tilt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Picture area (a doodle for now; real photos come later).
              Expanded(
                child: Container(
                  color: letter.tint,
                  alignment: Alignment.center,
                  child: Icon(letter.icon, size: 32, color: AppColors.ink),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      letter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(11, weight: FontWeight.w700),
                    ),
                  ),
                  Text('${letter.date.day}', style: AppText.hand(18, color: AppColors.accent)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
