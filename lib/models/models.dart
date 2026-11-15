/// The four kinds of things Dear Today keeps.
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

/// One moment in the diary timeline: some text, maybe a few photos.
class DiaryEntry {
  final String id;
  final DateTime at;
  final String text;
  final List<String> photos; // encrypted photos (.dtp)

  const DiaryEntry({required this.id, required this.at, required this.text, required this.photos});

  DiaryEntry copyWith({String? text, List<String>? photos}) =>
      DiaryEntry(id: id, at: at, text: text ?? this.text, photos: photos ?? this.photos);

  Map<String, dynamic> toJson() => {'id': id, 'at': at.toIso8601String(), 'text': text, 'photos': photos};

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        text: j['text'] as String? ?? '',
        photos: (j['photos'] as List? ?? const []).cast<String>(),
      );
}

/// A few seconds of video for the daily vlog.
class VlogClip {
  final String id;
  final DateTime recordedAt; // the time shown in the middle of the clip
  final int durationMs;
  final String path; // encrypted video (.dtv)
  final String quality; // '720p' or '1080p'

  const VlogClip({
    required this.id,
    required this.recordedAt,
    required this.durationMs,
    required this.path,
    required this.quality,
  });

  Duration get duration => Duration(milliseconds: durationMs);

  VlogClip withPath(String path) =>
      VlogClip(id: id, recordedAt: recordedAt, durationMs: durationMs, path: path, quality: quality);

  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': recordedAt.toIso8601String(),
        'durationMs': durationMs,
        'path': path,
        'quality': quality,
      };

  factory VlogClip.fromJson(Map<String, dynamic> j) => VlogClip(
        id: j['id'] as String,
        recordedAt: DateTime.parse(j['recordedAt'] as String),
        durationMs: j['durationMs'] as int? ?? 0,
        path: j['path'] as String,
        quality: j['quality'] as String? ?? '720p',
      );
}
