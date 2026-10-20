import 'package:flutter/material.dart';

import '../data/letter_store.dart';
import '../models/letter.dart';
import '../theme.dart';
import '../utils/dates.dart';
import '../widgets/postmark.dart';
import '../widgets/ruled_paper.dart';
import '../widgets/stamp.dart';
import '../widgets/stamp_picture.dart';
import 'write_photo_screen.dart';

/// Reading a sealed letter.
class LetterScreen extends StatelessWidget {
  final Letter letter;
  const LetterScreen({super.key, required this.letter});

  void _edit(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WritePhotoScreen(draft: LetterDraft.fromLetter(letter))),
      );

  Future<void> _delete(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete this letter?', style: AppText.hand(28)),
        content: Text(
          'This removes "${letter.title}" and its photo from Dear Today. It can\'t be undone.',
          style: AppText.body(14, weight: FontWeight.w500),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    await LetterStore.instance.delete(letter);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context); // grab it before leaving this screen
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Letter deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final mood = moodFor(letter.mood);
    final number = LetterStore.instance.numberInMonth(letter);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to letters',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left, color: AppColors.ink),
                  ),
                  const SizedBox(width: 48), // balances the two buttons on the right
                  Expanded(
                    child: Text('Letter No. $number', textAlign: TextAlign.center, style: AppText.hand(24)),
                  ),
                  IconButton(
                    tooltip: 'Edit letter',
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit_outlined, color: AppColors.ink),
                  ),
                  IconButton(
                    tooltip: 'Delete letter',
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 300,
                height: 290,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: StampFrame(
                        holeRadius: 4.5,
                        tilt: -2,
                        child: SizedBox(
                          width: 210,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: StampPicture(photoPath: letter.photoPath, doodle: letter.doodle, iconSize: 72),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('DEAR TODAY POST',
                                      style: AppText.body(10, weight: FontWeight.w800, color: AppColors.inkSoft)
                                          .copyWith(letterSpacing: 1.4)),
                                  const Spacer(),
                                  Text('${letter.date.day}', style: AppText.hand(26, color: AppColors.accent)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(right: -6, top: -6, child: Postmark(date: letter.date, size: 80)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RuledPaper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(letter.title.toUpperCase(),
                        style: AppText.body(11, weight: FontWeight.w800, color: AppColors.inkSoft)
                            .copyWith(letterSpacing: 1.4)),
                    const SizedBox(height: 10),
                    Text('Dear ${weekdayName(letter.date)},', style: AppText.hand(30)),
                    const SizedBox(height: 4),
                    Text(letter.body, style: AppText.body(15, weight: FontWeight.w500).copyWith(height: 2)),
                    Align(alignment: Alignment.centerRight, child: Text('— me', style: AppText.hand(22))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 15, color: AppColors.inkSoft),
                        const SizedBox(width: 4),
                        Text('Sealed ${clockTime(letter.sealedAt)}',
                            style: AppText.body(12, weight: FontWeight.w700, color: AppColors.inkSoft)),
                        const SizedBox(width: 14),
                        Icon(mood.icon, size: 16, color: AppColors.inkSoft),
                        const SizedBox(width: 4),
                        Text(mood.label, style: AppText.body(12, weight: FontWeight.w700, color: AppColors.inkSoft)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
