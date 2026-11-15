/// Small date helpers so screens can say "Sun, 15 Nov" or "6:42 PM"
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

/// "November 2026"
String monthYear(DateTime d) => '${monthName(d)} ${d.year}';

/// "Sun, 15 Nov"
String shortDate(DateTime d) => '${shortWeekday(d)}, ${d.day} ${shortMonth(d)}';

/// "Sunday, 15 November"
String longDate(DateTime d) => '${weekdayName(d)}, ${d.day} ${monthName(d)}';

/// "15 NOV 26" (for postmarks)
String postmarkDate(DateTime d) =>
    '${d.day} ${shortMonth(d).toUpperCase()} ${(d.year % 100).toString().padLeft(2, '0')}';

/// "6:42" and "PM", separately.
String clockDigits(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')}';
}

String amPm(DateTime d) => d.hour < 12 ? 'AM' : 'PM';

/// "6:42 PM"
String clockTime(DateTime d) => '${clockDigits(d)} ${amPm(d)}';

/// "0:07" for durations.
String shortDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime monthOnly(DateTime d) => DateTime(d.year, d.month);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

/// "1st", "2nd", "3rd", "4th"...
String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
}

/// "1.24 GB", "860 MB", "312 KB"
String fileSize(int bytes) {
  if (bytes >= 1000 * 1000 * 1000) return '${(bytes / 1e9).toStringAsFixed(2)} GB';
  if (bytes >= 1000 * 1000) return '${(bytes / 1e6).round()} MB';
  if (bytes >= 1000) return '${(bytes / 1e3).round()} KB';
  return '$bytes B';
}
