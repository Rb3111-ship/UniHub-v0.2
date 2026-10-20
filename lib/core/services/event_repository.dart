import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';

/// Source of events. [SupabaseEventRepository] is the real one;
/// [MockEventRepository] keeps tests and offline demos working.
abstract class EventRepository {
  /// Published events that have not ended yet, soonest first.
  /// Row Level Security decides what the signed-in user may see.
  Future<List<Event>> fetchUpcoming();

  /// Publishes [event]. [tenantId] is null for public (commercial) events.
  Future<Event> create(Event event, {required String? tenantId});
}

class SupabaseEventRepository implements EventRepository {
  SupabaseEventRepository(this._client, this._domainForSlug);

  final SupabaseClient _client;

  /// Maps a university slug (e.g. "tum") to its e-mail domain (e.g. "tum.de").
  final String Function(String slug) _domainForSlug;

  static const _select = '*, tenants(slug)';

  Event _fromRow(Map<String, dynamic> row) {
    final slug = (row['tenants'] as Map?)?['slug'] as String?;
    final imagePath = row['image_path'] as String?;
    return Event.fromRow(
      row,
      universityDomain: slug == null ? '' : _domainForSlug(slug),
      imageUrl: imagePath == null
          ? null
          : _client.storage.from('event-images').getPublicUrl(imagePath),
    );
  }

  @override
  Future<List<Event>> fetchUpcoming() async {
    final rows = await _client
        .from('events')
        .select(_select)
        .eq('status', 'published')
        .gte('ends_at', DateTime.now().toUtc().toIso8601String())
        .order('starts_at');
    return rows.map<Event>(_fromRow).toList();
  }

  @override
  Future<Event> create(Event event, {required String? tenantId}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Not signed in');
    }
    final row = await _client
        .from('events')
        .insert({
          'tenant_id': tenantId,
          'organizer_id': user.id,
          'title': event.title.trim(),
          'description': event.description.trim(),
          'location': event.location.trim(),
          'starts_at': event.date.toUtc().toIso8601String(),
          'ends_at': event.endDate.toUtc().toIso8601String(),
          'capacity': event.capacity,
          'price_cents': 0,
          'requires_qr': event.requiresQrCode,
          'allow_reviews': event.allowReviews,
          'categories': event.categories,
          'status': 'published',
        })
        .select(_select)
        .single();
    return _fromRow(row);
  }
}

class MockEventRepository implements EventRepository {
  final List<Event> _events = [
    Event(
      id: 'evt-1',
      title: 'TUM Hackathon 2026',
      description: 'Collaborate with fellow students to build innovative solutions for smart city challenges. Food and drinks provided!',
      date: DateTime.now().add(const Duration(days: 4)),
      location: 'Interdisciplinary Research Center, Garching',
      universityDomain: 'tum.de',
      isUniversityOfficial: true,
      requiresQrCode: true,
      allowReviews: true,
      categories: const ['Tech', 'Academic'],
      imageUrl: 'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800',
    ),
    Event(
      id: 'evt-2',
      title: 'LMU Summer Theater Festival',
      description: 'Experience an outdoor theatrical performance of William Shakespeare\'s "A Midsummer Night\'s Dream" by LMU drama students.',
      date: DateTime.now().add(const Duration(days: 12)),
      location: 'LMU Main Campus Courtyard',
      universityDomain: 'lmu.de',
      isUniversityOfficial: true,
      requiresQrCode: false,
      allowReviews: true,
      categories: const ['Arts', 'Music'],
      imageUrl: 'https://images.unsplash.com/photo-1460723237483-7a6dc9d0b212?w=800',
    ),
    Event(
      id: 'evt-3',
      title: 'Spring Campus Concert',
      description: 'Join us for an evening of live music, food stalls, and community under the stars. Free entry for all students.',
      date: DateTime.now().add(const Duration(days: 2)),
      location: 'TUM Main Campus Lawn',
      universityDomain: 'tum.de',
      isUniversityOfficial: true,
      requiresQrCode: true,
      allowReviews: false,
      categories: const ['Music', 'Other'],
      imageUrl: 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=800',
    ),
    Event(
      id: 'evt-4',
      title: 'Isar Summer Music Festival',
      description: 'A weekend public music festival along the banks of the Isar River featuring local artists, indie bands, and food trucks.',
      date: DateTime.now().add(const Duration(days: 6)),
      location: 'Flaucher Grounds, Isar',
      universityDomain: '',
      isUniversityOfficial: false,
      requiresQrCode: false,
      allowReviews: true,
      categories: const ['Music', 'Other'],
      imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800',
    ),
    Event(
      id: 'evt-5',
      title: 'Munich Marathon Student Training',
      description: 'Get ready for the Munich Marathon with a guided group run! Open to all fitness levels. Meet near the English Garden entrance.',
      date: DateTime.now().add(const Duration(days: 8)),
      location: 'English Garden Entrance',
      universityDomain: '',
      isUniversityOfficial: false,
      requiresQrCode: false,
      allowReviews: false,
      categories: const ['Sports', 'Other'],
      imageUrl: 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=800',
    ),
  ];

  /// Synchronous snapshot, soonest first (used to seed state without a loading flash).
  List<Event> get all {
    _events.sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(_events);
  }

  @override
  Future<List<Event>> fetchUpcoming() async => all;

  @override
  Future<Event> create(Event event, {required String? tenantId}) async {
    _events.add(event);
    return event;
  }
}
