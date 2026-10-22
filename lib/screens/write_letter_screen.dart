import 'package:flutter/material.dart';

import '../data/letter_store.dart';
import '../data/settings_store.dart';
import '../models/letter.dart';
import '../theme.dart';
import '../utils/dates.dart';
import '../widgets/buttons.dart';
import '../widgets/ruled_paper.dart';
import '../widgets/stamp.dart';
import '../widgets/stamp_picture.dart';
import '../widgets/step_header.dart';
import 'sealed_screen.dart';

/// Step 2: write "Dear Tuesday, ..." and pick a mood.
class WriteLetterScreen extends StatefulWidget {
  final LetterDraft draft;
  const WriteLetterScreen({super.key, required this.draft});

  @override
  State<WriteLetterScreen> createState() => _WriteLetterScreenState();
}

class _WriteLetterScreenState extends State<WriteLetterScreen> {
  late final _title = TextEditingController(text: widget.draft.title);
  late final _body = TextEditingController(text: widget.draft.body);
  bool _sealing = false;

  LetterDraft get draft => widget.draft;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _seal() async {
    if (_body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a little something to today first ✎')),
      );
      return;
    }
    setState(() => _sealing = true);
    try {
      final letter = await LetterStore.instance.seal(draft);
      if (!mounted) return;
      // Go to the "Sealed!" screen; going back from there returns to the album.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => SealedScreen(letter: letter, edited: draft.isEditing)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sealing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t save the letter: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hintStyle = AppText.body(15, weight: FontWeight.w500, color: const Color(0xFF7D87A3));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(
              step: 2,
              title: draft.headerTitle,
              leadingIcon: Icons.chevron_left,
              onLeading: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                children: [
                  RuledPaper(
                    firstLine: 98,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(stampDate(draft.date).toUpperCase(),
                                      style: AppText.body(11, weight: FontWeight.w800, color: AppColors.inkSoft)
                                          .copyWith(letterSpacing: 1.4)),
                                  TextField(
                                    controller: _title,
                                    onChanged: (v) => draft.title = v,
                                    maxLength: 24,
                                    textCapitalization: TextCapitalization.sentences,
                                    style: AppText.body(14, weight: FontWeight.w700),
                                    decoration: InputDecoration(
                                      hintText: 'Name this moment',
                                      hintStyle: hintStyle.copyWith(fontSize: 14),
                                      border: InputBorder.none,
                                      counterText: '',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.only(top: 6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Greeting sits beside the stamp, under the date and title.
                                  Text('Dear ${weekdayName(draft.date)},', style: AppText.hand(30)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            StampFrame(
                              holeRadius: 2.6,
                              tilt: 4,
                              child: SizedBox(
                                width: 54,
                                height: 64,
                                child: StampPicture(photoPath: draft.photoPath, doodle: draft.doodle, iconSize: 26),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _body,
                          onChanged: (v) => draft.body = v,
                          minLines: 5,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppText.letter(),
                          decoration: InputDecoration(
                            hintText: 'Tell today what happened…',
                            hintStyle: hintStyle,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.only(top: 4),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('— ${SettingsStore.instance.signOff}', style: AppText.hand(22, color: const Color(0xFF7D87A3))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('How did today feel?', style: AppText.body(13, weight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final m in moods)
                        _MoodChoice(
                          mood: m,
                          selected: draft.mood == m.key,
                          onTap: () => setState(() => draft.mood = m.key),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: ChunkyButton(
                label: draft.isEditing ? 'Reseal the letter' : 'Seal the letter',
                icon: Icons.verified_outlined,
                busy: _sealing,
                onTap: _seal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChoice extends StatelessWidget {
  final Mood mood;
  final bool selected;
  final VoidCallback onTap;
  const _MoodChoice({required this.mood, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: mood.label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.accent.withValues(alpha: 0.12) : AppColors.white,
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.line,
                  width: selected ? 2 : 1.5,
                ),
              ),
              child: Icon(mood.icon, color: selected ? AppColors.ink : AppColors.iconSoft, size: 28),
            ),
            const SizedBox(height: 4),
            Text(mood.label, style: AppText.body(11, weight: FontWeight.w700, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
