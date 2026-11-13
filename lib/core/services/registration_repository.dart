import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../models/registration_model.dart';

/// Registrations, tickets and door check-in, all backed by database functions
/// (`register_for_event`, `cancel_registration`, `check_in_ticket`) so capacity,
/// the waitlist and ticket validity are enforced on the server.
/// How long a ticket stays under "Past events" after its event ended.
const pastTicketsKept = Duration(days: 90);

class RegistrationRepository {
  RegistrationRepository(this._client, this._domainForSlug);

  final SupabaseClient _client;
  final String Function(String slug) _domainForSlug;

  Event _eventFromRow(Map<String, dynamic> row) {
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

  /// All of the current user's non-cancelled registrations, soonest event first.
  Future<List<Registration>> fetchMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('registrations')
        .select('id, status, confirm_asked_at, confirmed_at, events!inner(*, tenants(slug)), '
            'tickets(code, ticket_number, checked_in_at, voided_at)')
        .eq('user_id', uid)
        .neq('status', 'cancelled')
        // Tickets of events that ended more than 90 days ago are no longer listed.
        .gte('events.ends_at', DateTime.now().toUtc().subtract(pastTicketsKept).toIso8601String());

    final result = <Registration>[];
    for (final row in rows) {
      final eventRow = row['events'];
      if (eventRow is! Map<String, dynamic>) continue; // event no longer visible
      // A unique foreign key makes PostgREST return one object; tolerate a list too.
      final t = row['tickets'];
      final ticket = t is List ? (t.isEmpty ? null : t.first as Map<String, dynamic>) : t as Map<String, dynamic>?;
      result.add(Registration(
        id: row['id'] as String,
        event: _eventFromRow(eventRow),
        status: Registration.parseStatus(row['status'] as String),
        ticketCode: ticket?['code'] as String?,
        ticketNumber: ticket?['ticket_number'] as int?,
        checkedInAt: ticket?['checked_in_at'] == null
            ? null
            : DateTime.parse(ticket!['checked_in_at'] as String).toLocal(),
        ticketVoided: ticket?['voided_at'] != null,
        confirmAskedAt: _time(row['confirm_asked_at']),
        confirmedAt: _time(row['confirmed_at']),
      ));
    }
    result.sort((a, b) => a.event.date.compareTo(b.event.date));
    return result;
  }

  /// Registers for [eventId]; returns the resulting status (registered or waitlisted).
  Future<RegistrationStatus> register(String eventId) async {
    final row = await _client.rpc('register_for_event', params: {'p_event_id': eventId});
    return Registration.parseStatus((row as Map<String, dynamic>)['status'] as String);
  }

  static DateTime? _time(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

  /// "Yes, I'm still coming."
  Future<void> confirm(String eventId) async {
    await _client.rpc('confirm_attendance', params: {'p_event_id': eventId});
  }

  Future<void> cancel(String eventId) async {
    await _client.rpc('cancel_registration', params: {'p_event_id': eventId});
  }

  /// Door check-in for an event the current user organizes.
  Future<CheckInResult> checkIn(String code, String eventId) async {
    final json = await _client.rpc('check_in_ticket', params: {'p_code': code, 'p_event_id': eventId});
    return CheckInResult.fromJson(json as Map<String, dynamic>);
  }

  /// Events the current user organizes (any status), newest first.
  /// [organizerId]: another organizer's events, for a teammate (the server
  /// only returns them to members of that team).
  Future<List<Event>> fetchManagedEvents({String? organizerId}) async {
    final uid = organizerId ?? _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('events')
        .select('*, tenants(slug)')
        .eq('organizer_id', uid)
        .order('starts_at', ascending: false);
    return rows.map<Event>(_eventFromRow).toList();
  }
}
