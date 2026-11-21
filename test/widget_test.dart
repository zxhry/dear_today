import 'package:flutter_test/flutter_test.dart';
import 'package:dear_today/models/models.dart';
import 'package:dear_today/utils/dates.dart';

void main() {
  test('stamps survive a save/load round trip', () {
    final original = Stamp(
      id: '1',
      takenAt: DateTime(2026, 11, 14, 18, 42),
      title: 'Rain cleared before sunset',
      place: 'Home',
      setId: null,
      photoPath: '/x/1.dtp',
      shape: StampShape.square,
    );
    final copy = Stamp.fromJson(original.toJson());
    expect(copy.title, original.title);
    expect(copy.takenAt, original.takenAt);
    expect(copy.shape, StampShape.square);
    expect(copy.setId, isNull);
  });

  test('diary entries and clips survive a round trip', () {
    final e = DiaryEntry(id: '2', at: DateTime(2026, 11, 15, 13, 15), text: 'kopi after the lab', photos: const ['a.dtp']);
    expect(DiaryEntry.fromJson(e.toJson()).photos, ['a.dtp']);
    final c = VlogClip(id: '3', recordedAt: DateTime(2026, 11, 15, 18, 58), durationMs: 5000, path: 'c.dtv', quality: '720p');
    expect(VlogClip.fromJson(c.toJson()).duration, const Duration(seconds: 5));
  });

  test('mood, prompt, tags and reel order survive a round trip', () {
    final e = DiaryEntry(
      id: '4',
      at: DateTime(2026, 11, 21, 21, 5),
      text: 'Small wins #Campus walk #study #campus',
      photos: const [],
      mood: 'Calm',
      prompt: 'What made today feel different?',
    );
    final copy = DiaryEntry.fromJson(e.toJson());
    expect(copy.mood, 'Calm');
    expect(copy.prompt, e.prompt);
    expect(copy.tags, ['campus', 'study']);
    expect(copy.words, 6);
    final c = VlogClip(
        id: '5', recordedAt: DateTime(2026, 11, 21, 8, 42), durationMs: 4000, path: 'd.dtv', quality: '720p', reelIndex: 2);
    expect(VlogClip.fromJson(c.toJson()).reelIndex, 2);
    expect(VlogClip.fromJson(c.withReelIndex(null).toJson()).reelIndex, isNull);
  });

  test('date helpers', () {
    final d = DateTime(2026, 11, 15, 18, 58);
    expect(shortDate(d), 'Sun, 15 Nov');
    expect(clockTime(d), '6:58 PM');
    expect(postmarkDate(d), '15 NOV 26');
    expect(ordinal(5), '5th');
    expect(ordinal(22), '22nd');
    expect(fileSize(1240000000), '1.24 GB');
  });
}
