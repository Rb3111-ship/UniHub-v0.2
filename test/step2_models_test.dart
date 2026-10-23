import 'package:flutter_test/flutter_test.dart';
import 'package:uni_events_app/core/models/admin_model.dart';
import 'package:uni_events_app/core/models/event_model.dart';

void main() {
  test('Event.fromRow reads status and image path', () {
    final e = Event.fromRow({
      'id': 'e1',
      'title': 'Film night',
      'location': 'Hall',
      'starts_at': '2030-01-01T18:00:00Z',
      'ends_at': '2030-01-01T20:00:00Z',
      'tenant_id': null,
      'requires_qr': false,
      'allow_reviews': true,
      'categories': ['Arts'],
      'status': 'cancelled',
      'image_path': 'abc/def.png',
    }, universityDomain: '');
    expect(e.isCancelled, isTrue);
    expect(e.imagePath, 'abc/def.png');
  });

  test('Event defaults to published without an image', () {
    final e = Event(
      id: 'x', title: 't', description: '', date: DateTime(2030), location: 'l',
      universityDomain: '', isUniversityOfficial: false, requiresQrCode: false,
      allowReviews: false, categories: const ['Other'],
    );
    expect(e.status, 'published');
    expect(e.isCancelled, isFalse);
    expect(e.imagePath, isNull);
  });

  test('OrganizerRequest.fromRow reads the applicant name and status', () {
    final r = OrganizerRequest.fromRow({
      'id': 'r1',
      'user_id': 'u1',
      'email': 'a@b.de',
      'requested_role': 'commercial_planner',
      'organization_name': 'Acme',
      'message': 'hi',
      'status': 'pending',
      'review_note': null,
      'created_at': '2030-01-01T10:00:00Z',
      'profiles': {'display_name': 'Ann'},
    });
    expect(r.displayName, 'Ann');
    expect(r.isPending, isTrue);
    expect(r.isCommercial, isTrue);
  });

  test('OrganizerRequest copes with a missing profile', () {
    final r = OrganizerRequest.fromRow({
      'id': 'r2', 'user_id': 'u2', 'email': '', 'requested_role': 'organizer',
      'organization_name': 'Club', 'message': '', 'status': 'approved',
      'review_note': 'ok', 'created_at': '2030-01-01T10:00:00Z', 'profiles': null,
    });
    expect(r.displayName, '');
    expect(r.isPending, isFalse);
  });

  test('AdminUser.fromRow', () {
    final u = AdminUser.fromRow({
      'id': 'u', 'display_name': null, 'email': 'x@y.de', 'role': 'organizer',
      'tenant_id': null, 'organizer_verified': true, 'created_at': '2030-01-01T10:00:00Z',
    });
    expect(u.displayName, '');
    expect(u.organizerVerified, isTrue);
  });
}
