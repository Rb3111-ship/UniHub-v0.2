/// One row of the planner dashboard (see the `event_stats` database view).
class EventStat {
  final String eventId;
  final String title;
  final int? capacity; // null = unlimited
  final int registered;
  final int waitlisted;
  final int checkedIn;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status; // draft | published | cancelled
  final double? averageRating; // verified reviews only
  final int reviewCount;

  const EventStat({
    required this.eventId,
    required this.title,
    required this.capacity,
    required this.registered,
    required this.waitlisted,
    required this.checkedIn,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.averageRating,
    required this.reviewCount,
  });

  factory EventStat.fromRow(Map<String, dynamic> row) => EventStat(
        eventId: row['event_id'] as String,
        title: row['title'] as String,
        capacity: row['capacity'] as int?,
        registered: (row['registered'] as int?) ?? 0,
        waitlisted: (row['waitlisted'] as int?) ?? 0,
        checkedIn: (row['checked_in'] as int?) ?? 0,
        startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(row['ends_at'] as String).toLocal(),
        status: row['status'] as String,
        averageRating: (row['avg_rating'] as num?)?.toDouble(),
        reviewCount: (row['review_count'] as int?) ?? 0,
      );

  bool get isActive => status == 'published' && endsAt.isAfter(DateTime.now());

  /// Share of registered people who showed up (0..1).
  double get attendanceShare => registered == 0 ? 0 : (checkedIn / registered).clamp(0.0, 1.0);

  /// How full the event is (0..1); unlimited events fall back to attendance.
  double get fillShare =>
      capacity == null ? attendanceShare : (registered / capacity!).clamp(0.0, 1.0);
}

/// One line of the door scan log.
class ScanEntry {
  final String result; // granted | already_used | invalid | wrong_event | cancelled
  final DateTime scannedAt;
  final int? ticketNumber;
  final String eventTitle;

  const ScanEntry({
    required this.result,
    required this.scannedAt,
    required this.ticketNumber,
    required this.eventTitle,
  });

  factory ScanEntry.fromRow(Map<String, dynamic> row) {
    final ticket = row['tickets'];
    final event = row['events'];
    return ScanEntry(
      result: row['result'] as String,
      scannedAt: DateTime.parse(row['scanned_at'] as String).toLocal(),
      ticketNumber: ticket is Map ? ticket['ticket_number'] as int? : null,
      eventTitle: event is Map ? (event['title'] as String? ?? '') : '',
    );
  }

  bool get ok => result == 'granted';

  String get ticketDisplayId =>
      ticketNumber == null ? '' : 'TKT-${ticketNumber.toString().padLeft(6, '0')}';
}

/// Everything the planner dashboard shows.
class DashboardData {
  final List<EventStat> stats;
  final List<ScanEntry> scans;

  const DashboardData({this.stats = const [], this.scans = const []});

  int get totalRegistered => stats.fold(0, (sum, s) => sum + s.registered);
  int get totalCheckedIn => stats.fold(0, (sum, s) => sum + s.checkedIn);
  int get activeEvents => stats.where((s) => s.isActive).length;

  /// Percentage 0..100 of registered people who were checked in.
  double get attendanceRate =>
      totalRegistered == 0 ? 0 : (totalCheckedIn / totalRegistered) * 100;
}

/// Verified average rating of an event, as shown to students.
class EventRating {
  final double average;
  final int count;
  const EventRating(this.average, this.count);
}
