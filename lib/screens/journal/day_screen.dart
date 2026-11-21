import 'package:flutter/material.dart';

import '../../data/journal_store.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';
import 'moment_tile.dart';

/// Everything kept on one day, as a timeline.
class DayScreen extends StatelessWidget {
  final DateTime day;
  const DayScreen({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final store = JournalStore.instance;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final moments = store.momentsOn(day);
          return ListView(
            padding: EdgeInsets.fromLTRB(20, pageTop(context, pushed: true), 20, pad.bottom + 32),
            children: [
              const TopBar(),
              PageHeader(
                label: '${weekdayName(day)}${day.year == DateTime.now().year ? '' : ' ${day.year}'} · '
                    '${momentSummary(moments)}',
                title: '${day.day} ${monthName(day)}',
              ),
              const SizedBox(height: headerGap),
              if (moments.isEmpty)
                const EmptyNote(icon: Icons.today_outlined, text: 'Nothing was kept on this day.')
              else
                DayTimeline(moments: moments),
            ],
          );
        },
      ),
    );
  }
}
