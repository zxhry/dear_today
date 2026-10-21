import 'dart:async';

import 'package:flutter/widgets.dart';

import '../utils/dates.dart';

/// Notices when the date changes, so screens that show "today" (the album,
/// calendar, and mailbox letters that unlock at midnight) refresh by
/// themselves instead of showing yesterday until the app is restarted.
///
/// It checks at midnight while the app is open, and again whenever you
/// come back to the app (a phone asleep overnight may skip the midnight timer).
class DayClock extends ChangeNotifier {
  DayClock._();
  static final instance = DayClock._();

  DateTime _today = dayOnly(DateTime.now());
  Timer? _timer;
  AppLifecycleListener? _life;

  DateTime get today => _today;

  void start() {
    _life ??= AppLifecycleListener(onResume: _check);
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _timer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    // A second after midnight, to be safely on the new day.
    _timer = Timer(midnight.difference(now) + const Duration(seconds: 1), _check);
  }

  void _check() {
    final now = dayOnly(DateTime.now());
    if (now != _today) {
      _today = now;
      notifyListeners();
    }
    _scheduleMidnight();
  }
}
