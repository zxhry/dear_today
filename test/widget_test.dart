import 'package:flutter_test/flutter_test.dart';
import 'package:dear_today/models/letter.dart';

void main() {
  test('sample letters are newest first', () {
    for (var i = 1; i < sampleLetters.length; i++) {
      expect(sampleLetters[i - 1].date.isAfter(sampleLetters[i].date), isTrue);
    }
  });
}
