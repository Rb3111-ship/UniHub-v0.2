/// One entry of the in-app notification list (the same messages are sent as push).
class AppNotification {
  final int id;
  /// event_cancelled | event_changed | waitlist_promoted | reminder |
  /// request_approved | request_rejected | event_removed
  final String kind;
  final String? eventId;
  final String eventTitle;
  final DateTime? eventStartsAt;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.eventId,
    required this.eventTitle,
    required this.eventStartsAt,
    required this.createdAt,
    required this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    final starts = (row['events'] as Map?)?['starts_at'] as String?;
    final read = row['read_at'] as String?;
    return AppNotification(
      id: (row['id'] as num).toInt(),
      kind: row['kind'] as String,
      eventId: row['event_id'] as String?,
      eventTitle: (row['event_title'] as String?) ?? '',
      eventStartsAt: starts == null ? null : DateTime.parse(starts).toLocal(),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      readAt: read == null ? null : DateTime.parse(read).toLocal(),
    );
  }

  AppNotification markedRead() => AppNotification(
        id: id,
        kind: kind,
        eventId: eventId,
        eventTitle: eventTitle,
        eventStartsAt: eventStartsAt,
        createdAt: createdAt,
        readAt: readAt ?? DateTime.now(),
      );
}
