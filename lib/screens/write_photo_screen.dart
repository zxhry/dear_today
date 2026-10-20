import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/letter.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/stamp.dart';
import '../widgets/stamp_picture.dart';
import '../widgets/step_header.dart';
import 'write_letter_screen.dart';

/// Step 1: choose today's photo, or a doodle stamp.
class WritePhotoScreen extends StatefulWidget {
  final LetterDraft draft;
  const WritePhotoScreen({super.key, required this.draft});

  @override
  State<WritePhotoScreen> createState() => _WritePhotoScreenState();
}

class _WritePhotoScreenState extends State<WritePhotoScreen> {
  final _picker = ImagePicker();
  LetterDraft get draft => widget.draft;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file != null) setState(() => draft.photoPath = file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t open the photo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(
              step: 1,
              title: draft.headerTitle,
              leadingIcon: Icons.close,
              leadingTooltip: 'Close',
              onLeading: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  children: [
                    Text('What moment is today?', textAlign: TextAlign.center, style: AppText.hand(32)),
                    const SizedBox(height: 6),
                    Text('Pick one photo. It becomes today\'s stamp.',
                        textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.inkSoft)),
                    const SizedBox(height: 24),
                    _BigStamp(draft: draft, onTapEmpty: () => _pick(ImageSource.gallery)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SoftButton(
                            label: 'Camera',
                            icon: Icons.photo_camera_outlined,
                            onTap: () => _pick(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SoftButton(
                            label: 'Gallery',
                            icon: Icons.photo_outlined,
                            onTap: () => _pick(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text('No photo today? Pick a doodle stamp',
                        style: AppText.body(13, weight: FontWeight.w700, color: AppColors.inkSoft)),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final d in doodles)
                          _DoodleChoice(
                            doodle: d,
                            selected: draft.photoPath == null && draft.doodle == d.key,
                            onTap: () => setState(() {
                              draft.doodle = d.key;
                              draft.photoPath = null;
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: ChunkyButton(
                label: 'Next: write the letter',
                icon: Icons.arrow_forward,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WriteLetterScreen(draft: draft)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigStamp extends StatelessWidget {
  final LetterDraft draft;
  final VoidCallback onTapEmpty;
  const _BigStamp({required this.draft, required this.onTapEmpty});

  @override
  Widget build(BuildContext context) {
    return StampFrame(
      holeRadius: 5,
      tilt: -2,
      child: SizedBox(
        width: 220,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Semantics(
                button: true,
                label: 'Choose a photo from your gallery',
                child: GestureDetector(
                  onTap: onTapEmpty,
                  child: StampPicture(photoPath: draft.photoPath, doodle: draft.doodle, iconSize: 72),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('DEAR TODAY POST',
                    style: AppText.body(10, weight: FontWeight.w800, color: AppColors.inkSoft)
                        .copyWith(letterSpacing: 1.4)),
                const Spacer(),
                Text('${draft.date.day}', style: AppText.hand(26, color: AppColors.accent)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoodleChoice extends StatelessWidget {
  final Doodle doodle;
  final bool selected;
  final VoidCallback onTap;
  const _DoodleChoice({required this.doodle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: doodle.name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: doodle.tint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.ink,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: Icon(doodle.icon, color: AppColors.ink),
        ),
      ),
    );
  }
}
