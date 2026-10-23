import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_model.dart';

/// The "current password" typed when changing the password was wrong.
class WrongPasswordException implements Exception {
  const WrongPasswordException();
}

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

  /// Changes the password only after the current one has been confirmed, so someone
  /// holding an unlocked phone cannot lock the owner out.
  /// Throws [WrongPasswordException] if [currentPassword] is wrong.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw const AuthException('Not signed in');
    try {
      await _client.auth.signInWithPassword(email: email, password: currentPassword);
    } on AuthApiException catch (e) {
      if (e.code == 'invalid_credentials') throw const WrongPasswordException();
      rethrow;
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword, currentPassword: currentPassword));
  }

  /// Removes the account and all of the user's data. Files the user uploaded are
  /// deleted first because the database cannot delete storage blobs itself.
  Future<void> deleteMyAccount() async {
    for (final name in ['event-images', 'avatars']) {
      final bucket = _client.storage.from(name);
      final files = await bucket.list(path: _uid);
      if (files.isNotEmpty) {
        await bucket.remove(files.map((f) => '$_uid/${f.name}').toList());
      }
    }
    await _client.rpc('delete_my_account');
  }

  // ---- profile photo (organizers and admins) -------------------------------

  String avatarUrl(String path) => _client.storage.from('avatars').getPublicUrl(path);

  /// Uploads a new photo, points the profile at it and removes the old file.
  Future<String> uploadAvatar(Uint8List bytes, String contentType, String extension, String? oldPath) async {
    final path = '$_uid/avatar-${DateTime.now().millisecondsSinceEpoch}.$extension';
    final bucket = _client.storage.from('avatars');
    await bucket.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));
    await _client.from('profiles').update({'avatar_path': path}).eq('id', _uid);
    if (oldPath != null && oldPath != path) {
      try {
        await bucket.remove([oldPath]);
      } catch (_) {
        // A leftover old file is harmless; the profile already points at the new one.
      }
    }
    return path;
  }

  Future<void> removeAvatar(String path) async {
    await _client.from('profiles').update({'avatar_path': null}).eq('id', _uid);
    try {
      await _client.storage.from('avatars').remove([path]);
    } catch (_) {
      // The profile no longer shows it; the file is removed with the account at the latest.
    }
  }

  /// Everything the platform stores about the signed-in user, as readable JSON.
  Future<String> exportMyData() async {
    final user = _client.auth.currentUser!;
    final profile = await _client
        .from('profiles')
        .select('display_name, role, locale, organizer_verified, created_at, tenants(name_en)')
        .eq('id', _uid)
        .maybeSingle();
    final registrations = await _client
        .from('registrations')
        .select('status, created_at, events(title, starts_at, location), tickets(ticket_number, checked_in_at)')
        .eq('user_id', _uid);
    final reviews =
        await _client.from('reviews').select('rating, comment, is_verified, created_at, events(title)').eq('user_id', _uid);
    final requests = await _client
        .from('organizer_requests')
        .select('requested_role, organization_name, message, status, created_at')
        .eq('user_id', _uid);
    return const JsonEncoder.withIndent('  ').convert({
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'account': {'email': user.email, 'created_at': user.createdAt},
      'profile': profile,
      'registrations': registrations,
      'reviews': reviews,
      'organizer_requests': requests,
    });
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
        .select('*, profiles!organizer_requests_user_id_fkey(display_name)')
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
        .select('*, profiles!organizer_requests_user_id_fkey(display_name)')
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
