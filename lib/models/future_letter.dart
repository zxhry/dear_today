/// A letter to tomorrow: written today, sealed until [openOn].
class FutureLetter {
  final String id;
  final DateTime writtenAt;
  final DateTime openOn; // the day it arrives (unlocks at [deliveryHour])
  final String body;
  final DateTime? openedAt; // null until you first read it

  const FutureLetter({
    required this.id,
    required this.writtenAt,
    required this.openOn,
    required this.body,
    this.openedAt,
  });

  /// Letters to tomorrow arrive (unlock, and you get a notification) at 7:00 am.
  /// Change this one number to move the delivery time (24-hour clock).
  static const deliveryHour = 7;

  /// The exact moment this letter arrives.
  DateTime get arrivesAt => DateTime(openOn.year, openOn.month, openOn.day, deliveryHour);

  bool get opened => openedAt != null;

  FutureLetter markOpened() =>
      FutureLetter(id: id, writtenAt: writtenAt, openOn: openOn, body: body, openedAt: DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'writtenAt': writtenAt.toIso8601String(),
        'openOn': openOn.toIso8601String(),
        'body': body,
        'openedAt': openedAt?.toIso8601String(),
      };

  factory FutureLetter.fromJson(Map<String, dynamic> j) => FutureLetter(
        id: j['id'] as String,
        writtenAt: DateTime.parse(j['writtenAt'] as String),
        openOn: DateTime.parse(j['openOn'] as String),
        body: j['body'] as String? ?? '',
        openedAt: j['openedAt'] == null ? null : DateTime.parse(j['openedAt'] as String),
      );
}
