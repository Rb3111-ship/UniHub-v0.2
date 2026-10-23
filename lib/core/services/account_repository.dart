import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_model.dart';

/// Profile edits, organizer requests, admin tools and account deletion.
/// Every rule (who may approve whom, who may delete) is enforced in the database.
class AccountRepository {
  AccountRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<String?> fetchLocale() async {
    final row = await _client.from('profiles').select('locale').eq('id', _uid).maybeSingle();
    return row?['locale'] as String?;
  }

  Future<void> saveLocale(String code) async {
    await _client.from('profiles').update({'locale': code}).eq('id', _uid);
  }

  Future<void> updateDisplayName(String name) async {
    await _client.from('profiles').update({'display_name': name.trim()}).eq('id', _uid);
  }

  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Removes the account and all of the user's data. Files the user uploaded are
  /// deleted first because the database cannot delete storage blobs itself.
  Future<void> deleteMyAccount() async {
    final bucket = _client.storage.from('event-images');
    final files = await bucket.list(path: _uid);
    if (files.isNotEmpty) {
      await bucket.remove(files.map((f) => '$_uid/${f.name}').toList());
    }
    await _client.rpc('delete_my_account');
  }

  // ---- organizer requests ---------------------------------------------------

  Future<void> requestOrganizerAccess(String role, String organization, String message) async {
    await _client.rpc('request_organizer_access', params: {
      'p_role': role,
      'p_org': organization,
      'p_message': message,
    });
  }

  /// The user's most recent request, if any.
  Future<OrganizerRequest?> fetchMyLatestRequest() async {
    final rows = await _client
        .from('organizer_requests')
        .select('*, profiles(display_name)')
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : OrganizerRequest.fromRow(rows.first);
  }

  // ---- admin ---------------------------------------------------------------

  /// Requests the signed-in admin is allowed to see, pending first.
  Future<List<OrganizerRequest>> fetchRequests() async {
    final rows = await _client
        .from('organizer_requests')
        .select('*, profiles(display_name)')
        .order('created_at', ascending: false)
        .limit(100);
    final list = rows.map<OrganizerRequest>(OrganizerRequest.fromRow).toList();
    list.sort((a, b) => a.isPending == b.isPending ? 0 : (a.isPending ? -1 : 1));
    return list;
  }

  Future<void> reviewRequest(String id, bool approve, String? note) async {
    await _client.rpc('review_organizer_request', params: {
      'p_request': id,
      'p_approve': approve,
      'p_note': note,
    });
  }

  Future<List<AdminUser>> listUsers(String search) async {
    final rows = await _client.rpc('admin_list_users', params: {'p_search': search, 'p_limit': 100});
    return (rows as List).map((r) => AdminUser.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<void> setRole(String userId, String role, bool verified) async {
    await _client.rpc('admin_set_role', params: {
      'p_user': userId,
      'p_role': role,
      'p_verified': verified,
    });
  }
}
