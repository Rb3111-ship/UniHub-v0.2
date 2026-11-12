import 'package:flutter/material.dart';
import '../../core/widgets/ticket_stub.dart';
import '../../core/widgets/page_width.dart';
import '../../../core/widgets/empty_state.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/push_service.dart';
import 'details_screen.dart';
import 'review_screen.dart';

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
    'review_prompt' => (l10n.notifReviewPromptTitle, l10n.notifReviewPromptBody(t)),
    'account_suspended' => (l10n.notifSuspendedTitle, l10n.notifSuspendedBody),
    'account_reinstated' => (l10n.notifReinstatedTitle, l10n.notifReinstatedBody),
    'email_check_due' => (l10n.notifEmailCheckDueTitle, l10n.notifEmailCheckDueBody),
    'email_check_lapsed' => (l10n.notifEmailCheckLapsedTitle, l10n.notifEmailCheckLapsedBody),
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
      'review_prompt' => Icons.star_rate_rounded,
      'account_suspended' => Icons.pause_circle_filled_rounded,
      'account_reinstated' => Icons.check_circle_rounded,
      'email_check_due' || 'email_check_lapsed' => Icons.mark_email_unread_rounded,
      _ => Icons.notifications_rounded,
    };

/// Opens the event a notification or push message points to. A review invitation
/// opens the review form instead, unless the review was already written.
Future<void> openNotificationEvent(BuildContext context, String eventId, {String? kind}) async {
  final appState = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final gone = AppLocalizations.of(context)!.notificationsEventGone;
  final event = await appState.eventById(eventId);
  if (event == null) {
    messenger.showSnackBar(SnackBar(content: Text(gone)));
    return;
  }
  if (kind == 'review_prompt' && !appState.hasReviewed(event.id)) {
    navigator.push(MaterialPageRoute(builder: (_) => StudentReviewScreen(event: event)));
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
          if (items.isNotEmpty)
            IconButton(
              tooltip: l10n.notificationsDeleteAll,
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () => _deleteAll(context, appState, l10n),
            ),
        ],
      ),
      body: PageWidth(maxWidth: 760, child: RefreshIndicator(
        onRefresh: appState.refreshNotifications,
        child: items.isEmpty
            ? ListView(children: [
                const SizedBox(height: 40),
                EmptyState(icon: Icons.notifications_none_rounded, title: l10n.notificationsEmpty),
              ])
            : ListView.separated(
                itemCount: items.length + 1,
                separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(l10n.notificationsSwipeHint,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                    );
                  }
                  final n = items[index - 1];
                  final (title, body) = notificationText(l10n, n);
                  final background = Container(
                    color: theme.colorScheme.errorContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: AlignmentDirectional.centerEnd,
                    child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onErrorContainer),
                  );
                  return Dismissible(
                    key: ValueKey('notification-${n.id}'),
                    background: Container(
                      color: theme.colorScheme.errorContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: AlignmentDirectional.centerStart,
                      child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onErrorContainer),
                    ),
                    secondaryBackground: background,
                    onDismissed: (_) async {
                      final messenger = ScaffoldMessenger.of(context);
                      final failed = l10n.notificationsDeleteFailed;
                      if (!await appState.deleteNotifications([n.id])) {
                        messenger.showSnackBar(SnackBar(content: Text(failed)));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(_icon(n.kind), color: theme.colorScheme.onPrimaryContainer),
                          ),
                          title: Text(title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(body),
                              const SizedBox(height: 2),
                              Text(dateFormat.format(n.createdAt).toUpperCase(),
                                  style: monoStyle(size: 10, color: theme.colorScheme.secondary, spacing: 0.6)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing:
                              n.isRead ? null : Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
                          onTap: () {
                            appState.markNotificationsRead([n.id]);
                            if (n.eventId != null) openNotificationEvent(context, n.eventId!, kind: n.kind);
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
      )),
    );
  }

  Future<void> _deleteAll(BuildContext context, AppState appState, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notificationsDeleteAllTitle),
        content: Text(l10n.notificationsDeleteAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.notificationsDeleteAll)),
        ],
      ),
    );
    if (ok != true) return;
    if (!await appState.deleteNotifications()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.notificationsDeleteFailed)));
    }
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
