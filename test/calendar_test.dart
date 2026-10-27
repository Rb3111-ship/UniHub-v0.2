import 'package:flutter_test/flutter_test.dart';
import 'package:uni_events_app/core/models/event_model.dart';
import 'package:uni_events_app/core/utils/add_to_calendar.dart';

void main() {
  test('Google Calendar link carries title, place and UTC times', () {
    final event = Event(
      id: 'e1',
      title: 'Film & Pizza',
      description: '',
      date: DateTime.utc(2026, 11, 3, 18, 30),
      endDate: DateTime.utc(2026, 11, 3, 21),
      location: 'Room 5',
      universityDomain: '',
      isUniversityOfficial: false,
      requiresQrCode: false,
      allowReviews: false,
      categories: const ['Arts'],
    );
    final uri = googleCalendarLink(event, 'Bring snacks');
    expect(uri.scheme, 'https');
    expect(uri.host, 'calendar.google.com');
    expect(uri.queryParameters['text'], 'Film & Pizza');
    expect(uri.queryParameters['dates'], '20261103T183000Z/20261103T210000Z');
    expect(uri.queryParameters['location'], 'Room 5');
    expect(uri.queryParameters['details'], 'Bring snacks');
  });
}
