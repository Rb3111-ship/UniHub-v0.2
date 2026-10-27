import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_model.dart';

/// Saved events (favourites) and event reports. Who may see or change what is
/// enforced by the database (row level security and functions).
class CommunityRepository {
  CommunityRepository(this._client);

  final SupabaseClient _client;

  // ---- favourites -----------------------------------------------------------

  Future<Set<String>> fetchFavoriteIds() async {
    final rows = await _client.from('favorites').select('event_id');
    return {for (final r in rows) r['event_id'] as String};
  }

  Future<void> addFavorite(String eventId) async {
    await _client.from('favorites').insert({'event_id': eventId});
  }

  Future<void> removeFavorite(String eventId) async {
    await _client.from('favorites').delete().eq('event_id', eventId);
  }

  // ---- reports --------------------------------------------------------------

  Future<void> reportEvent(String eventId, String reason, String details) async {
    await _client.rpc('report_event', params: {
      'p_event': eventId,
      'p_reason': reason,
      'p_details': details,
    });
  }

  /// Reports the signed-in admin may act on (their own reports are filtered out
  /// by the caller when needed), open ones first.
  Future<List<EventReport>> fetchReports() async {
    final rows = await _client
        .from('event_reports')
        .select('*, events(title, starts_at, status)')
        .order('created_at', ascending: false)
        .limit(200);
    final list = rows.map<EventReport>(EventReport.fromRow).toList();
    list.sort((a, b) => a.isOpen == b.isOpen ? 0 : (a.isOpen ? -1 : 1));
    return list;
  }

  Future<void> resolveReport(String id, bool remove, String? note) async {
    await _client.rpc('resolve_report', params: {
      'p_report': id,
      'p_remove': remove,
      'p_note': note,
    });
  }
}
