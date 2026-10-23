import 'package:flutter_test/flutter_test.dart';
import 'package:uni_events_app/core/auth/user_role.dart';
import 'package:uni_events_app/core/models/dashboard_model.dart';
import 'package:uni_events_app/core/models/review_model.dart';

Map<String, dynamic> _statRow({
  String id = 'e1',
  int? capacity = 10,
  int registered = 4,
  int checkedIn = 2,
  String status = 'published',
  Object? avg = 4.5,
  int reviews = 2,
}) =>
    {
      'event_id': id,
      'title': 'Event $id',
      'capacity': capacity,
      'registered': registered,
      'waitlisted': 1,
      'checked_in': checkedIn,
      'starts_at': '2030-01-01T10:00:00Z',
      'ends_at': '2030-01-01T12:00:00Z',
      'status': status,
      'avg_rating': avg,
      'review_count': reviews,
    };

void main() {
  group('EventStat', () {
    test('parses a database row', () {
      final s = EventStat.fromRow(_statRow());
      expect(s.title, 'Event e1');
      expect(s.averageRating, 4.5);
      expect(s.reviewCount, 2);
      expect(s.isActive, isTrue); // published and ends in 2030
    });

    test('fill share uses capacity, or attendance when unlimited', () {
      expect(EventStat.fromRow(_statRow(capacity: 8, registered: 4)).fillShare, 0.5);
      expect(EventStat.fromRow(_statRow(capacity: null, registered: 4, checkedIn: 1)).fillShare, 0.25);
    });

    test('no division by zero and no rating when nobody registered', () {
      final s = EventStat.fromRow(_statRow(registered: 0, checkedIn: 0, avg: null, reviews: 0));
      expect(s.attendanceShare, 0);
      expect(s.fillShare, 0);
      expect(s.averageRating, isNull);
    });

    test('draft events are not active', () {
      expect(EventStat.fromRow(_statRow(status: 'draft')).isActive, isFalse);
    });
  });

  group('DashboardData', () {
    test('sums registrations and check-ins across events', () {
      final d = DashboardData(stats: [
        EventStat.fromRow(_statRow(id: 'a', registered: 10, checkedIn: 5)),
        EventStat.fromRow(_statRow(id: 'b', registered: 10, checkedIn: 3)),
      ]);
      expect(d.totalRegistered, 20);
      expect(d.totalCheckedIn, 8);
      expect(d.attendanceRate, closeTo(40, 0.001));
      expect(d.activeEvents, 2);
    });

    test('attendance rate is 0 with no registrations', () {
      expect(const DashboardData().attendanceRate, 0);
    });
  });

  test('ScanEntry reads the joined ticket and event', () {
    final e = ScanEntry.fromRow({
      'result': 'granted',
      'scanned_at': '2030-01-01T10:00:00Z',
      'tickets': {'ticket_number': 42},
      'events': {'title': 'Hack Night'},
    });
    expect(e.ok, isTrue);
    expect(e.ticketDisplayId, 'TKT-000042');
    expect(e.eventTitle, 'Hack Night');
  });

  test('ScanEntry copes with an unknown ticket (invalid code)', () {
    final e = ScanEntry.fromRow({
      'result': 'invalid',
      'scanned_at': '2030-01-01T10:00:00Z',
      'tickets': null,
      'events': {'title': 'Hack Night'},
    });
    expect(e.ok, isFalse);
    expect(e.ticketDisplayId, '');
  });

  test('Review.fromRow maps the verified flag', () {
    final r = Review.fromRow({
      'id': 'r1',
      'event_id': 'e1',
      'rating': 4,
      'comment': 'Great',
      'created_at': '2030-01-01T10:00:00Z',
      'is_verified': true,
      'claimed_attendance': true,
    });
    expect(r.rating, 4.0);
    expect(r.isVerified, isTrue);
  });

  group('ratings in mock mode', () {
    test('only verified reviews count', () {
      final state = AppState();
      // Seed data: evt-1 has one verified 5-star review; evt-4 only an unverified one.
      expect(state.ratingFor('evt-1')?.average, 5.0);
      expect(state.ratingFor('evt-1')?.count, 1);
      expect(state.ratingFor('evt-4'), isNull);
    });

    test('an event with no reviews has no rating (no invented 4.5)', () {
      expect(AppState().ratingFor('evt-5'), isNull);
    });
  });
}
