import 'package:flutter/material.dart';
import '../models/letter.dart';
import '../theme.dart';
import '../utils/dates.dart';
import 'stamp.dart';
import 'stamp_picture.dart';

/// One small stamp in the album grid: picture, short title, day number.
class LetterStamp extends StatelessWidget {
  final Letter letter;
  final double tilt;
  final VoidCallback? onTap;

  const LetterStamp({super.key, required this.letter, this.tilt = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${letter.title}, ${letter.date.day} ${monthName(letter.date)}',
      child: GestureDetector(
        onTap: onTap,
        child: StampFrame(
          tilt: tilt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: StampPicture(photoPath: letter.photoPath, doodle: letter.doodle)),
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
