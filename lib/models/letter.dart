import 'package:flutter/material.dart';
import '../theme.dart';

/// A doodle stamp, used when a day has no photo.
class Doodle {
  final String key;
  final String name;
  final IconData icon;
  final Color tint;
  const Doodle(this.key, this.name, this.icon, this.tint);
}

const doodles = <Doodle>[
  Doodle('sunny', 'Sunny', Icons.wb_sunny_outlined, AppColors.butter),
  Doodle('rainy', 'Rainy', Icons.water_drop_outlined, AppColors.sky),
  Doodle('cosy', 'Cosy drink', Icons.local_cafe_outlined, AppColors.peach),
  Doodle('night', 'Night', Icons.nightlight_outlined, AppColors.lavender),
  Doodle('love', 'Love', Icons.favorite_border, AppColors.sage),
  Doodle('study', 'Study', Icons.menu_book_outlined, AppColors.lavender),
  Doodle('bloom', 'Bloom', Icons.local_florist_outlined, AppColors.sage),
];

Doodle doodleFor(String key) =>
    doodles.firstWhere((d) => d.key == key, orElse: () => doodles.first);

/// How the day felt.
class Mood {
  final String key;
  final String label;
  final IconData icon;
  const Mood(this.key, this.label, this.icon);
}

const moods = <Mood>[
  Mood('down', 'Down', Icons.sentiment_very_dissatisfied_outlined),
  Mood('meh', 'Meh', Icons.sentiment_neutral_outlined),
  Mood('cosy', 'Cosy', Icons.sentiment_satisfied_outlined),
  Mood('happy', 'Happy', Icons.sentiment_satisfied_alt_outlined),
  Mood('excited', 'Excited', Icons.sentiment_very_satisfied_outlined),
];

Mood moodFor(String key) => moods.firstWhere((m) => m.key == key, orElse: () => moods[2]);

/// One day's sealed letter.
class Letter {
  final String id;
  final DateTime date; // the day the letter is for
  final DateTime sealedAt; // the exact moment it was sealed
  final String title; // short name shown on the album stamp
  final String body;
  final String mood;
  final String doodle;
  final String? photoPath; // copy of the photo inside the app's private folder

  const Letter({
    required this.id,
    required this.date,
    required this.sealedAt,
    required this.title,
    required this.body,
    required this.mood,
    required this.doodle,
    this.photoPath,
  });

  /// The same letter pointing at a different photo file.
  Letter withPhoto(String? path) => Letter(
        id: id,
        date: date,
        sealedAt: sealedAt,
        title: title,
        body: body,
        mood: mood,
        doodle: doodle,
        photoPath: path,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'sealedAt': sealedAt.toIso8601String(),
        'title': title,
        'body': body,
        'mood': mood,
        'doodle': doodle,
        'photoPath': photoPath,
      };

  factory Letter.fromJson(Map<String, dynamic> j) => Letter(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        sealedAt: DateTime.parse(j['sealedAt'] as String),
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        mood: j['mood'] as String? ?? 'cosy',
        doodle: j['doodle'] as String? ?? 'sunny',
        photoPath: j['photoPath'] as String?,
      );
}

/// A letter that's still being written, or one being edited.
class LetterDraft {
  final DateTime date; // today for new letters; kept as-is when editing
  String? photoPath; // picked photo (temporary) or the letter's saved photo
  String doodle = 'rainy';
  String title = '';
  String body = '';
  String mood = 'cosy';
  final String? editingId; // set when editing an existing letter

  LetterDraft({required this.date, this.editingId});

  bool get isEditing => editingId != null;

  /// "Write to today", or "Edit letter" when changing an existing one.
  String get headerTitle => isEditing ? 'Edit letter' : 'Write to today';

  /// Start an edit from an existing letter, with everything filled in.
  factory LetterDraft.fromLetter(Letter l) => LetterDraft(date: l.date, editingId: l.id)
    ..photoPath = l.photoPath
    ..doodle = l.doodle
    ..title = l.title
    ..body = l.body
    ..mood = l.mood;
}
