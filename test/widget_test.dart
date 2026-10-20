import 'package:flutter_test/flutter_test.dart';
import 'package:dear_today/models/letter.dart';
import 'package:dear_today/utils/dates.dart';

void main() {
  test('letters survive a save/load round trip', () {
    final original = Letter(
      id: '1',
      date: DateTime(2026, 10, 20),
      sealedAt: DateTime(2026, 10, 20, 17, 42),
      title: 'First rain',
      body: 'Waited out the rain at the café.',
      mood: 'cosy',
      doodle: 'rainy',
    );
    final copy = Letter.fromJson(original.toJson());
    expect(copy.title, original.title);
    expect(copy.body, original.body);
    expect(copy.date, original.date);
    expect(copy.photoPath, isNull);
  });

  test('date helpers', () {
    final d = DateTime(2026, 10, 20, 17, 42);
    expect(weekdayName(d), 'Tuesday');
    expect(stampDate(d), 'Tue · 20 Oct 2026');
    expect(clockTime(d), '5:42 pm');
  });
}
