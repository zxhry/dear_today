import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/letter_store.dart';
import '../data/settings_store.dart';

/// The daily "write to today" reminder.
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
    await reschedule();
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
