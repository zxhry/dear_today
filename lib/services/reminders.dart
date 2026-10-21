import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/letter_store.dart';
import '../data/settings_store.dart';
import '../data/tomorrow_store.dart';
import '../models/future_letter.dart';
import 'day_clock.dart';

/// Dear Today's notifications:
/// - the daily "write to today" reminder, and
/// - "you've got mail" when a letter to tomorrow arrives (at [mailHour]).
///
/// Instead of one repeating alarm, it schedules the next [_daysAhead]
/// evenings one by one, so it can skip any day you've already written.
/// The schedule is refreshed when the app opens and whenever letters change.
/// No letter content ever appears in a notification.
class Reminders {
  Reminders._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _daysAhead = 14;
  static const _firstId = 100; // ids 100..113 belong to reminders
  static bool _ready = false;

  static const _firstMailId = 200; // ids 200..229 belong to mail deliveries
  static const _maxMail = 30;
  static const mailHour = FutureLetter.deliveryHour; // same moment the letter unlocks

  /// True when Android lets us schedule reminders on the dot.
  static bool onTime = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      // A new channel id: Android fixes a channel's importance when it's
      // first created, so the banner version needs its own channel.
      'daily_reminder_banner',
      'Daily reminder',
      channelDescription: 'A gentle nudge to write to today',
      importance: Importance.high, // high = slides down as a banner over other apps
      priority: Priority.high,
      icon: 'ic_stat_dear_today',
      color: Color(0xFFC24E3B),
    ),
  );

  static const _mailDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'mailbox_delivery',
      'Mail from yesterday\'s you',
      channelDescription: 'When a letter to tomorrow arrives in your mailbox',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_dear_today',
      color: Color(0xFFC24E3B),
    ),
  );

  static const _bodies = [
    'How was your day? Seal a little moment before it ends.',
    'Today has a story. Want to write it down?',
    'A photo, a few words, a stamp. That\'s all it takes.',
    'Your album has an empty spot for today.',
  ];

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_dear_today'),
      ),
    );
    _ready = true;
    // Remove the earlier, quieter channel so it doesn't linger in settings.
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.deleteNotificationChannel(channelId: 'daily_reminder');
    } catch (_) {}
    // Whenever letters change (sealed, deleted, restored), refresh the plan.
    LetterStore.instance.addListener(reschedule);
    DayClock.instance.addListener(reschedule); // a new day: plan from today again
    // Letters to tomorrow: sealed, opened or deleted -> refresh deliveries.
    TomorrowStore.instance.addListener(rescheduleMail);
    DayClock.instance.addListener(rescheduleMail);
    await reschedule();
    await rescheduleMail();
  }

  /// Asks Android (13+) for permission to show notifications.
  static Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  /// Opens Android's "Alarms & reminders" switch so reminders can be on time.
  static Future<void> requestOnTime() async {
    await _android?.requestExactAlarmsPermission();
    await reschedule();
  }

  /// "Dear myokohi," (or "Dear you," before you've set a name in the Me tab).
  static String _greeting() {
    final name = SettingsStore.instance.name;
    return 'Dear ${name.isEmpty ? 'you' : name},';
  }

  /// One "you've got mail" notification per delivery day, for letters that
  /// haven't been opened yet. Opening a letter early cancels its notification.
  static Future<void> rescheduleMail() async {
    if (!_ready) return;
    try {
      for (var i = 0; i < _maxMail; i++) {
        await _plugin.cancel(id: _firstMailId + i);
      }
      onTime = await _android?.canScheduleExactNotifications() ?? false;
      final store = TomorrowStore.instance;
      final days = {for (final f in [...store.waiting, ...store.arrived]) f.openOn}.toList()..sort();
      final now = DateTime.now();
      var n = 0;
      for (final day in days) {
        if (n >= _maxMail) break;
        final at = DateTime(day.year, day.month, day.day, mailHour);
        if (!at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: _firstMailId + n,
          title: _greeting(),
          body: 'A letter from yesterday\'s you has arrived in your mailbox ✉',
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: _mailDetails,
          androidScheduleMode:
              onTime ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        );
        debugPrint('Mail delivery planned for $at');
        n++;
      }
    } catch (e) {
      debugPrint('Could not schedule mail deliveries: $e');
    }
  }

  static Future<void> reschedule() async {
    if (!_ready) return;
    try {
      for (var i = 0; i < _daysAhead; i++) {
        await _plugin.cancel(id: _firstId + i);
      }
      final s = SettingsStore.instance;
      onTime = await _android?.canScheduleExactNotifications() ?? false;
      if (!s.reminderOn) return;

      final now = DateTime.now();
      final wroteToday = LetterStore.instance.forDay(now).isNotEmpty;
      for (var i = 0; i < _daysAhead; i++) {
        final at = DateTime(now.year, now.month, now.day + i, s.reminderHour, s.reminderMinute);
        if (!at.isAfter(now)) continue; // today's time has already passed
        if (i == 0 && wroteToday) continue; // already wrote today: no nudge tonight
        await _plugin.zonedSchedule(
          id: _firstId + i,
          title: _greeting(),
          body: _bodies[at.day % _bodies.length],
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: _details,
          // On time if you've allowed "Alarms & reminders", otherwise approximate.
          androidScheduleMode:
              onTime ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        );
        debugPrint('Reminder planned for $at (${onTime ? 'on time' : 'approximate'})');
      }
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint('Reminders waiting: ${pending.length}');
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }
}
