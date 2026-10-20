import 'package:flutter_test/flutter_test.dart';
import 'package:uni_events_app/core/auth/user_role.dart';
import 'package:uni_events_app/core/models/event_model.dart';

void main() {
  test('Event.fromRow maps a database row (official event)', () {
    final event = Event.fromRow(
      {
        'id': 'a1',
        'title': 'Hack Night',
        'description': null,
        'location': 'Room 1',
        'starts_at': '2026-11-01T18:00:00+00:00',
        'ends_at': '2026-11-01T22:00:00+00:00',
        'tenant_id': 't1',
        'requires_qr': true,
        'allow_reviews': false,
        'categories': ['Tech', 'Academic'],
        'capacity': 50,
        'price_cents': 0,
      },
      universityDomain: 'tum.de',
    );
    expect(event.isUniversityOfficial, isTrue);
    expect(event.universityDomain, 'tum.de');
    expect(event.description, '');
    expect(event.capacity, 50);
    expect(event.categories, ['Tech', 'Academic']);
    expect(event.endDate.difference(event.date), const Duration(hours: 4));
  });

  test('Event.fromRow treats a missing tenant as a public event', () {
    final event = Event.fromRow(
      {
        'id': 'b2',
        'title': 'Open Air',
        'location': 'Park',
        'starts_at': '2026-11-02T18:00:00Z',
        'ends_at': '2026-11-02T20:00:00Z',
        'tenant_id': null,
        'requires_qr': false,
        'allow_reviews': true,
        'categories': ['Music'],
        'capacity': null,
      },
      universityDomain: '',
    );
    expect(event.isUniversityOfficial, isFalse);
    expect(event.capacity, isNull);
  });

  test('mock mode publishes an event into the feed', () async {
    final state = AppState();
    final before = state.events.length;
    await state.addEvent(Event(
      id: 'x',
      title: 'New',
      description: '',
      date: DateTime.now().add(const Duration(days: 1)),
      location: 'Here',
      universityDomain: '',
      isUniversityOfficial: false,
      requiresQrCode: false,
      allowReviews: false,
      categories: const ['Other'],
    ));
    expect(state.events.length, before + 1);
  });
}
