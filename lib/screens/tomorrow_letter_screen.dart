import 'package:flutter/material.dart';

import '../data/tomorrow_store.dart';
import '../models/future_letter.dart';
import '../theme.dart';
import '../utils/dates.dart';
import '../widgets/postmark.dart';
import '../widgets/ruled_paper.dart';

/// Reading a letter from yesterday's you. Opening it marks it as read.
class TomorrowLetterScreen extends StatefulWidget {
  final FutureLetter letter;
  const TomorrowLetterScreen({super.key, required this.letter});

  @override
  State<TomorrowLetterScreen> createState() => _TomorrowLetterScreenState();
}

class _TomorrowLetterScreenState extends State<TomorrowLetterScreen> {
  late FutureLetter _letter = widget.letter;

  @override
  void initState() {
    super.initState();
    if (!_letter.opened) {
      TomorrowStore.instance.markOpened(_letter).then((updated) {
        if (mounted) setState(() => _letter = updated);
      });
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete this letter?', style: AppText.hand(28)),
        content: Text('It can\'t be undone.', style: AppText.body(14, weight: FontWeight.w500)),
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
    if (sure != true || !mounted) return;
    await TomorrowStore.instance.delete(_letter);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = _letter;
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
                    tooltip: 'Back to mailbox',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left, color: AppColors.ink),
                  ),
                  Expanded(
                    child: Text('From ${weekdayName(l.writtenAt)}\'s you',
                        textAlign: TextAlign.center, style: AppText.hand(24)),
                  ),
                  IconButton(
                    tooltip: 'Delete letter',
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  RuledPaper(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('WRITTEN ${stampDate(l.writtenAt).toUpperCase()}',
                            style: AppText.body(11, weight: FontWeight.w800, color: AppColors.inkSoft)
                                .copyWith(letterSpacing: 1.4)),
                        const SizedBox(height: 30),
                        Text('Dear Tomorrow,', style: AppText.hand(30)),
                        const SizedBox(height: 4),
                        Text(l.body, style: AppText.body(15, weight: FontWeight.w500).copyWith(height: 2)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('— ${weekdayName(l.writtenAt)}\'s me', style: AppText.hand(22)),
                        ),
                        if (l.openedAt != null) ...[
                          const SizedBox(height: 6),
                          Text('Opened ${longDate(l.openedAt!)}, ${clockTime(l.openedAt!)}',
                              style: AppText.body(12, weight: FontWeight.w700, color: AppColors.inkSoft)),
                        ],
                      ],
                    ),
                  ),
                  Positioned(right: -8, top: -22, child: Postmark(date: l.openOn, label: 'DELIVERED', size: 70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
