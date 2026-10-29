import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/push_service.dart';
import 'details_screen.dart';

/// Title and text of a notification in the app's language (push messages use the same wording).
(String, String) notificationText(AppLocalizations l10n, AppNotification n) {
  final t = n.eventTitle;
  return switch (n.kind) {
    'event_cancelled' => (l10n.notifEventCancelledTitle, l10n.notifEventCancelledBody(t)),
    'event_changed' => (l10n.notifEventChangedTitle, l10n.notifEventChangedBody(t)),
    'waitlist_promoted' => (l10n.notifWaitlistTitle, l10n.notifWaitlistBody(t)),
    'reminder' => (l10n.notifReminderTitle, l10n.notifReminderBody(t, _when(l10n.localeName, n.eventStartsAt))),
    'request_approved' => (l10n.notifRequestApprovedTitle, l10n.notifRequestApprovedBody),
    'request_rejected' => (l10n.notifRequestRejectedTitle, l10n.notifRequestRejectedBody),
    'event_removed' => (l10n.notifEventRemovedTitle, l10n.notifEventRemovedBody(t)),
    'confirm_attendance' => (l10n.notifConfirmTitle, l10n.notifConfirmBody(t)),
    'seat_released' => (l10n.notifSeatReleasedTitle, l10n.notifSeatReleasedBody(t)),
    _ => (l10n.notificationsTitle, t),
  };
}

String _when(String locale, DateTime? start) {
  final de = locale.startsWith('de');
  if (start == null) return de ? 'bald' : 'soon';
  return de
      ? 'am ${DateFormat('EEE d. MMM, HH:mm', 'de').format(start)} Uhr'
      : 'on ${DateFormat('EEE d MMM, HH:mm', 'en').format(start)}';
}

IconData _icon(String kind) => switch (kind) {
      'event_cancelled' || 'event_removed' => Icons.event_busy_rounded,
      'event_changed' => Icons.edit_calendar_rounded,
      'waitlist_promoted' => Icons.confirmation_number_rounded,
      'reminder' => Icons.alarm_rounded,
      'request_approved' => Icons.verified_rounded,
      'request_rejected' => Icons.info_outline_rounded,
      'confirm_attendance' => Icons.help_outline_rounded,
      'seat_released' => Icons.event_seat_rounded,
      _ => Icons.notifications_rounded,
    };

/// Opens the event a notification or push message points to.
Future<void> openNotificationEvent(BuildContext context, String eventId) async {
  final appState = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final gone = AppLocalizations.of(context)!.notificationsEventGone;
  final event = await appState.eventById(eventId);
  if (event == null) {
    messenger.showSnackBar(SnackBar(content: Text(gone)));
    return;
  }
  navigator.push(MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)));
}

/// Bell with the number of unread notifications; opens the list.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final unread = appState.unreadNotificationCount;
    return IconButton(
      tooltip: l10n.notificationsTitle,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: Icon(unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
      ),
      onPressed: () {
        appState.refreshNotifications();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      },
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final items = appState.notifications;
    final dateFormat = DateFormat.MMMd(l10n.localeName).add_Hm();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if (appState.unreadNotificationCount > 0)
            IconButton(
              tooltip: l10n.notificationsMarkAllRead,
              icon: const Icon(Icons.done_all_rounded),
              onPressed: () => appState.markNotificationsRead(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: appState.refreshNotifications,
        child: items.isEmpty
            ? ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    Icon(Icons.notifications_none_rounded, size: 56, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(l10n.notificationsEmpty, textAlign: TextAlign.center),
                  ]),
                ),
              ])
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = items[i];
                  final (title, body) = notificationText(l10n, n);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(_icon(n.kind), color: theme.colorScheme.onPrimaryContainer),
                    ),
                    title: Text(title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text('$body\n${dateFormat.format(n.createdAt)}'),
                    isThreeLine: true,
                    trailing: n.isRead
                        ? null
                        : Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
                    onTap: () {
                      appState.markNotificationsRead([n.id]);
                      if (n.eventId != null) openNotificationEvent(context, n.eventId!);
                    },
                  );
                },
              ),
      ),
    );
  }
}

/// Profile card: which notifications to get, and whether push works on this device.
class NotificationSettingsCard extends StatelessWidget {
  const NotificationSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    Future<void> save({bool? reminders, bool? updates}) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await appState.setNotificationSettings(reminders: reminders, updates: updates);
      } catch (_) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.notifSaveFailed)));
      }
    }

    final (statusIcon, statusText) = switch (appState.pushStatus) {
      PushStatus.on => (Icons.check_circle_rounded, l10n.notifPushOn),
      PushStatus.blocked => (Icons.notifications_off_rounded, l10n.notifPushBlocked),
      PushStatus.unavailable => (Icons.info_outline_rounded, l10n.notifPushUnavailable),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.alarm_rounded),
            title: Text(l10n.notifRemindersLabel),
            subtitle: Text(l10n.notifRemindersHint),
            value: appState.notifyReminders,
            onChanged: (v) => save(reminders: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.edit_calendar_rounded),
            title: Text(l10n.notifUpdatesLabel),
            subtitle: Text(l10n.notifUpdatesHint),
            value: appState.notifyUpdates,
            onChanged: (v) => save(updates: v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.notifAccountHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(statusIcon, size: 16, color: theme.colorScheme.secondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(statusText, style: theme.textTheme.bodySmall)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
