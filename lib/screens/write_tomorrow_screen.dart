import 'package:flutter/material.dart';

import '../data/tomorrow_store.dart';
import '../theme.dart';
import '../utils/dates.dart';
import '../widgets/buttons.dart';
import '../widgets/ruled_paper.dart';

/// Write a letter that stays sealed until tomorrow.
class WriteTomorrowScreen extends StatefulWidget {
  const WriteTomorrowScreen({super.key});

  @override
  State<WriteTomorrowScreen> createState() => _WriteTomorrowScreenState();
}

class _WriteTomorrowScreenState extends State<WriteTomorrowScreen> {
  final _body = TextEditingController();
  bool _sealing = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _seal() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_body.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Write a little something to tomorrow first ✎')));
      return;
    }
    setState(() => _sealing = true);
    await TomorrowStore.instance.add(_body.text);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Sealed! It\'ll be in your mailbox tomorrow. No peeking ✉')));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return Scaffold(
      body: SafeArea(
        child: Column(
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
                    child: Text('Write to tomorrow', textAlign: TextAlign.center, style: AppText.hand(24)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                children: [
                  RuledPaper(
                    firstLine: 62,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('OPENS ${stampDate(tomorrow).toUpperCase()}',
                            style: AppText.body(11, weight: FontWeight.w800, color: AppColors.inkSoft)
                                .copyWith(letterSpacing: 1.4)),
                        const SizedBox(height: 10),
                        Text('Dear Tomorrow,', style: AppText.hand(30)),
                        TextField(
                          controller: _body,
                          autofocus: true,
                          minLines: 6,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppText.letter(),
                          decoration: InputDecoration(
                            hintText: 'Something for tomorrow-you to read…',
                            hintStyle: AppText.body(15, weight: FontWeight.w500, color: const Color(0xFF7D87A3)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.only(top: 4),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('— today\'s me', style: AppText.hand(22, color: const Color(0xFF7D87A3))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.lock_clock_outlined, size: 18, color: AppColors.inkSoft),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Once sealed, it stays locked in your mailbox until ${weekdayName(tomorrow)}.',
                          style: AppText.body(13, color: AppColors.inkSoft),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: ChunkyButton(
                label: 'Seal until tomorrow',
                icon: Icons.lock_outline,
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
