import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

/// The signed-in user's notifications, their settings and their push devices.
class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<List<AppNotification>> fetch() async {
    final rows = await _client
        .from('notifications')
        .select('id, kind, event_id, event_title, created_at, read_at, events(starts_at)')
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map<AppNotification>(AppNotification.fromRow).toList();
  }

  Future<void> markRead(List<int> ids) async {
    if (ids.isEmpty) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids)
        .isFilter('read_at', null);
  }

  Future<void> delete(List<int> ids) async {
    if (ids.isEmpty) return;
    await _client.from('notifications').delete().inFilter('id', ids);
  }

  Future<void> saveSettings({bool? reminders, bool? updates}) async {
    await _client.from('profiles').update({
      if (reminders != null) 'notify_reminders': reminders,
      if (updates != null) 'notify_updates': updates,
    }).eq('id', _uid);
  }

  Future<void> registerDevice(String token, String platform) =>
      _client.rpc('register_push_token', params: {'p_token': token, 'p_platform': platform});

  Future<void> unregisterDevice(String token) =>
      _client.rpc('unregister_push_token', params: {'p_token': token});
}
