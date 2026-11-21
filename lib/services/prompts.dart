import '../utils/dates.dart';

/// The daily writing question on the Today page.
///
/// Each day gets its own question from the list below (the same one all
/// day). "Another prompt" moves to the next one.
class Prompts {
  static const all = [
    'What made today feel different from yesterday?',
    'What is one small thing you want to remember about today?',
    'Who did you talk to today, and what stayed with you?',
    'What did you see today that was quietly beautiful?',
    'What took most of your energy today?',
    'What are you looking forward to this week?',
    'What did you learn today, even something tiny?',
    'Where did you feel most at ease today?',
    'What made you laugh today?',
    'What would you tell yourself from this morning?',
    'What is something you finished today?',
    'What is on your mind right before sleeping?',
    'Which moment today would you film again?',
    'What did you eat today that was worth writing down?',
    'What sound or smell will remind you of today?',
    'What is one thing you are grateful for right now?',
    'What did you put off today, and why?',
    'Describe the light outside today.',
    'What was the best ten minutes of your day?',
    'What is something you want to do differently tomorrow?',
    'Which place did you pass by today that you want to go back to?',
    'What is a worry you can put down for tonight?',
    'What surprised you today?',
    'What did you do today just for yourself?',
    'Who would you like to thank, and for what?',
    'What did today teach you about yourself?',
    'If today had a title, what would it be?',
    'What are three words for how today felt?',
    'What small win are you proud of today?',
    'What did the weather do to your mood today?',
  ];

  /// "2026-11-21", used to remember skips for one day only.
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The question for [day], moved on [skip] times.
  static String forDay(DateTime day, int skip) {
    final start = DateTime(day.year);
    final n = dayOnly(day).difference(start).inDays + day.year;
    return all[(n + skip) % all.length];
  }
}
