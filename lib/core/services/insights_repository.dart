import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dashboard_model.dart';
import '../models/review_model.dart';

/// Reviews, ratings and planner dashboard data from Supabase.
///
/// What each user may read is decided by Row Level Security in the database:
/// students see verified reviews and their own, planners also see unverified
/// feedback on events they manage.
class InsightsRepository {
  InsightsRepository(this._client);

  final SupabaseClient _client;

  /// Verified average rating per event (what students see).
  Future<Map<String, EventRating>> fetchRatings() async {
    final rows = await _client.from('event_rating_stats').select();
    return {
      for (final r in rows)
        r['event_id'] as String: EventRating(
          (r['average_rating'] as num).toDouble(),
          r['review_count'] as int,
        ),
    };
  }

  /// Ids of events the current user has already reviewed.
  Future<Set<String>> fetchMyReviewedEventIds() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};
    final rows = await _client.from('reviews').select('event_id').eq('user_id', uid);
    return {for (final r in rows) r['event_id'] as String};
  }

  /// Sends a review. The server decides whether it counts as verified.
  Future<void> submitReview({
    required String eventId,
    required int rating,
    required String comment,
    required bool claimedAttendance,
  }) async {
    await _client.rpc('submit_review', params: {
      'p_event_id': eventId,
      'p_rating': rating,
      'p_comment': comment,
      'p_claimed_attendance': claimedAttendance,
    });
  }

  /// Per-event numbers for events the current user manages.
  Future<List<EventStat>> fetchStats() async {
    final rows = await _client.from('event_stats').select().order('starts_at', ascending: false);
    return rows.map<EventStat>(EventStat.fromRow).toList();
  }

  /// Most recent door scans for events the current user manages.
  Future<List<ScanEntry>> fetchRecentScans({int limit = 15}) async {
    final rows = await _client
        .from('scan_log')
        .select('result, scanned_at, tickets(ticket_number), events(title)')
        .order('scanned_at', ascending: false)
        .limit(limit);
    return rows.map<ScanEntry>(ScanEntry.fromRow).toList();
  }

  /// Feedback (verified and unverified) on events the current user manages,
  /// newest first, paired with the event title.
  Future<List<({Review review, String eventTitle})>> fetchFeedback() async {
    final rows = await _client
        .from('reviews')
        .select('*, events(title)')
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((r) {
      final event = r['events'];
      return (
        review: Review.fromRow(r),
        eventTitle: event is Map ? (event['title'] as String? ?? '') : '',
      );
    }).toList();
  }
}
