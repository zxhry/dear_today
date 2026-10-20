import 'package:flutter/material.dart';

import '../data/letter_store.dart';
import '../theme.dart';
import '../utils/dates.dart';
import '../widgets/letter_stamp.dart';
import 'letter_screen.dart';

/// One monthly bundle, untied: every letter of that month as stamps.
class MonthLettersScreen extends StatelessWidget {
  final DateTime month;
  const MonthLettersScreen({super.key, required this.month});

  static const _tilts = [-2.0, 1.5, 2.2, 1.8, -1.5, -2.2, -1.8, 2.0, 1.8];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: LetterStore.instance,
          builder: (context, _) {
            final letters = LetterStore.instance.inMonth(month.year, month.month);
            return Column(
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
                        child: Column(
                          children: [
                            Text(monthYear(month), style: AppText.hand(26)),
                            const SizedBox(height: 2),
                            Text('${letters.length} ${letters.length == 1 ? 'letter' : 'letters'}',
                                style: AppText.body(13, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: letters.length,
                    itemBuilder: (context, i) => LetterStamp(
                      letter: letters[i],
                      tilt: _tilts[i % _tilts.length],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => LetterScreen(letter: letters[i])),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
