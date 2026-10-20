/// Small date helpers so screens can say "Dear Tuesday," or "20 Oct 2026"
/// without pulling in a big date library.
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String weekdayName(DateTime d) => _weekdays[d.weekday - 1];
String shortWeekday(DateTime d) => weekdayName(d).substring(0, 3);
String monthName(DateTime d) => _months[d.month - 1];
String shortMonth(DateTime d) => monthName(d).substring(0, 3);

/// "October 2026"
String monthYear(DateTime d) => '${monthName(d)} ${d.year}';

/// "Tue · 20 Oct 2026"
String stampDate(DateTime d) => '${shortWeekday(d)} · ${d.day} ${shortMonth(d)} ${d.year}';

/// "Tue, 20 October"
String longDate(DateTime d) => '${shortWeekday(d)}, ${d.day} ${monthName(d)}';

/// "5:42 pm"
String clockTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'am' : 'pm'}';
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
