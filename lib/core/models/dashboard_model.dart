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
  final int confirmed; // said "yes, I'm coming"
  final int cancelled;
  final int released; // seats freed because nobody answered
  final bool requiresQr; // only then do we know who actually came

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
    this.confirmed = 0,
    this.cancelled = 0,
    this.released = 0,
    this.requiresQr = true,
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
        confirmed: (row['confirmed'] as int?) ?? 0,
        cancelled: (row['cancelled'] as int?) ?? 0,
        released: (row['released'] as int?) ?? 0,
        requiresQr: (row['requires_qr'] as bool?) ?? true,
      );

  bool get isActive => status == 'published' && endsAt.isAfter(DateTime.now());
  bool get hasStarted => startsAt.isBefore(DateTime.now());

  /// Share of seat holders who did not come (ticket events that have started).
  double? get noShowShare =>
      requiresQr && hasStarted && registered > 0 ? ((registered - checkedIn) / registered).clamp(0.0, 1.0) : null;

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

/// Extra numbers for one event's statistics page (`event_insights` database function).
class EventInsights {
  final Map<DateTime, int> signupsPerDay;
  final List<int> stars; // index 0 = 1 star ... index 4 = 5 stars
  final int verifiedReviews;
  final int asked; // got the "are you still coming?" question
  final int declined; // answered "I can't come"

  const EventInsights({
    this.signupsPerDay = const {},
    this.stars = const [0, 0, 0, 0, 0],
    this.verifiedReviews = 0,
    this.asked = 0,
    this.declined = 0,
  });

  factory EventInsights.fromJson(Map<String, dynamic> json) => EventInsights(
        signupsPerDay: {
          for (final d in (json['signups'] as List? ?? const []))
            DateTime.parse((d as Map)['day'] as String): (d['count'] as num).toInt(),
        },
        stars: [for (final n in (json['stars'] as List? ?? const [0, 0, 0, 0, 0])) (n as num).toInt()],
        verifiedReviews: (json['stars_verified'] as num?)?.toInt() ?? 0,
        asked: (json['asked'] as num?)?.toInt() ?? 0,
        declined: (json['declined'] as num?)?.toInt() ?? 0,
      );

  int get reviewCount => stars.fold(0, (a, b) => a + b);

  /// Average over all reviews (verified and unverified), or null without reviews.
  double? get averageStars {
    final n = reviewCount;
    if (n == 0) return null;
    var sum = 0;
    for (var i = 0; i < stars.length; i++) {
      sum += (i + 1) * stars[i];
    }
    return sum / n;
  }
}

/// Verified average rating of an event, as shown to students.
class EventRating {
  final double average;
  final int count;
  const EventRating(this.average, this.count);
}
