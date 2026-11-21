/// The kinds of things Dear Today keeps.
///
/// Every photo or video lives in the app's private folder, encrypted, and
/// these records only point at those files.
library;

/// The shape a stamp was pressed in.
enum StampShape {
  portrait(0.8),
  square(1.0),
  wide(1.33);

  /// Width divided by height.
  final double aspect;
  const StampShape(this.aspect);

  String get label => switch (this) {
        StampShape.portrait => 'Portrait',
        StampShape.square => 'Square',
        StampShape.wide => 'Wide',
      };

  static StampShape fromName(String? name) =>
      StampShape.values.firstWhere((s) => s.name == name, orElse: () => StampShape.portrait);
}

/// A photo of a nice place or moment, kept as a stamp.
class Stamp {
  final String id;
  final DateTime takenAt;
  final String title; // optional caption, "" when there's none
  final String place; // optional, "" when there's none
  final String? setId; // a set it also belongs to (it's always on its month's sheet)
  final String photoPath; // encrypted photo (.dtp)
  final StampShape shape;

  const Stamp({
    required this.id,
    required this.takenAt,
    required this.title,
    required this.place,
    required this.setId,
    required this.photoPath,
    required this.shape,
  });

  Stamp copyWith({String? title, String? place, String? setId, bool clearSet = false, String? photoPath}) => Stamp(
        id: id,
        takenAt: takenAt,
        title: title ?? this.title,
        place: place ?? this.place,
        setId: clearSet ? null : (setId ?? this.setId),
        photoPath: photoPath ?? this.photoPath,
        shape: shape,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'takenAt': takenAt.toIso8601String(),
        'title': title,
        'place': place,
        'setId': setId,
        'photoPath': photoPath,
        'shape': shape.name,
      };

  factory Stamp.fromJson(Map<String, dynamic> j) => Stamp(
        id: j['id'] as String,
        takenAt: DateTime.parse(j['takenAt'] as String),
        title: j['title'] as String? ?? '',
        place: j['place'] as String? ?? '',
        setId: j['setId'] as String?,
        photoPath: j['photoPath'] as String,
        shape: StampShape.fromName(j['shape'] as String?),
      );
}

/// A themed collection of stamps you make yourself ("Coffee runs").
class StampSet {
  final String id;
  final String name;
  final DateTime createdAt;

  const StampSet({required this.id, required this.name, required this.createdAt});

  StampSet renamed(String name) => StampSet(id: id, name: name, createdAt: createdAt);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'createdAt': createdAt.toIso8601String()};

  factory StampSet.fromJson(Map<String, dynamic> j) => StampSet(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Set',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// How a day felt, picked on a note. '' means none was picked.
const moods = ['Happy', 'Calm', 'Grateful', 'Tired', 'Low', 'Stressed'];

/// One moment in the diary timeline: some text, maybe a few photos.
class DiaryEntry {
  final String id;
  final DateTime at;
  final String text;
  final List<String> photos; // encrypted photos (.dtp)
  final String mood; // one of [moods], or ''
  final String prompt; // the daily question it answers, or ''

  const DiaryEntry({
    required this.id,
    required this.at,
    required this.text,
    required this.photos,
    this.mood = '',
    this.prompt = '',
  });

  /// The #tags written in the text, lower-case, without the #.
  List<String> get tags => tagsIn(text);

  /// The text for reading: tags at the end of a line are left out (they
  /// show as chips instead), and a tag inside a sentence loses its #.
  String get displayText => withoutTags(text);

  /// The number of words written.
  int get words => text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  DiaryEntry copyWith({String? text, List<String>? photos, String? mood, String? prompt}) => DiaryEntry(
        id: id,
        at: at,
        text: text ?? this.text,
        photos: photos ?? this.photos,
        mood: mood ?? this.mood,
        prompt: prompt ?? this.prompt,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'at': at.toIso8601String(), 'text': text, 'photos': photos, 'mood': mood, 'prompt': prompt};

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        text: j['text'] as String? ?? '',
        photos: (j['photos'] as List? ?? const []).cast<String>(),
        mood: j['mood'] as String? ?? '',
        prompt: j['prompt'] as String? ?? '',
      );
}

/// "Beli belah di Lotus #grocery" gives "Beli belah di Lotus", and
/// "Lunch at #campus with Aina" gives "Lunch at campus with Aina".
String withoutTags(String text) {
  final tag = r'#[\p{L}\p{N}_]+';
  final lines = <String>[];
  for (final line in text.split('\n')) {
    final cleaned = line
        .replaceAll(RegExp('(\\s*$tag)+\\s*\$', unicode: true), '')
        .replaceAllMapped(RegExp(tag, unicode: true), (m) => m.group(0)!.substring(1));
    // Drop a line that only held tags, but keep blank lines you wrote.
    if (cleaned.trim().isEmpty && line.trim().isNotEmpty) continue;
    lines.add(cleaned);
  }
  return lines.join('\n').trim();
}

/// "#Campus walk #study" gives ['campus', 'study'].
List<String> tagsIn(String text) {
  final found = <String>{};
  for (final m in RegExp(r'#([\p{L}\p{N}_]+)', unicode: true).allMatches(text)) {
    found.add(m.group(1)!.toLowerCase());
  }
  return found.toList();
}

/// A few seconds of video for the daily vlog.
class VlogClip {
  final String id;
  final DateTime recordedAt; // the time shown in the middle of the clip
  final int durationMs;
  final String path; // encrypted video (.dtv)
  final String quality; // '720p' or '1080p'
  final int? reelIndex; // its place in the day reel once you reorder; null = in time order

  const VlogClip({
    required this.id,
    required this.recordedAt,
    required this.durationMs,
    required this.path,
    required this.quality,
    this.reelIndex,
  });

  Duration get duration => Duration(milliseconds: durationMs);

  VlogClip withPath(String path) => VlogClip(
      id: id, recordedAt: recordedAt, durationMs: durationMs, path: path, quality: quality, reelIndex: reelIndex);

  VlogClip withReelIndex(int? i) =>
      VlogClip(id: id, recordedAt: recordedAt, durationMs: durationMs, path: path, quality: quality, reelIndex: i);

  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': recordedAt.toIso8601String(),
        'durationMs': durationMs,
        'path': path,
        'quality': quality,
        if (reelIndex != null) 'reelIndex': reelIndex,
      };

  factory VlogClip.fromJson(Map<String, dynamic> j) => VlogClip(
        id: j['id'] as String,
        recordedAt: DateTime.parse(j['recordedAt'] as String),
        durationMs: j['durationMs'] as int? ?? 0,
        path: j['path'] as String,
        quality: j['quality'] as String? ?? '720p',
        reelIndex: j['reelIndex'] as int?,
      );
}

/// One thing kept on a day, for the Today page and day timelines.
sealed class Moment {
  const Moment();
  DateTime get at;
}

class NoteMoment extends Moment {
  final DiaryEntry entry;
  const NoteMoment(this.entry);
  @override
  DateTime get at => entry.at;
}

class StampMoment extends Moment {
  final Stamp stamp;
  const StampMoment(this.stamp);
  @override
  DateTime get at => stamp.takenAt;
}

/// One or more clips recorded one after another.
class ClipsMoment extends Moment {
  final List<VlogClip> clips;
  const ClipsMoment(this.clips);
  @override
  DateTime get at => clips.first.recordedAt;
  Duration get total => clips.fold(Duration.zero, (sum, c) => sum + c.duration);
}
