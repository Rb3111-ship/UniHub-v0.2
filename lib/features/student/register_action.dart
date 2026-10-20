import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/models/event_model.dart';
import '../../core/models/registration_model.dart';

/// Registers the user for [event] and tells them what happened
/// (registered, waitlisted, or why it failed).
Future<void> registerWithFeedback(BuildContext context, AppState appState, Event event) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  try {
    final status = await appState.registerForEvent(event.id);
    messenger.showSnackBar(SnackBar(
      backgroundColor: status == RegistrationStatus.waitlisted ? Colors.orange : Colors.green,
      content: Text(status == RegistrationStatus.waitlisted
          ? l10n.registerWaitlisted(event.title)
          : l10n.registerSuccess(event.title)),
    ));
  } catch (e) {
    final text = switch (e is PostgrestException ? e.message : '') {
      'event_over' => l10n.registerEventOver,
      'event_not_available' => l10n.registerEventUnavailable,
      'paid_events_not_supported_yet' => l10n.registerPaidNotSupported,
      _ => l10n.registerFailed,
    };
    messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(text)));
  }
}

/// Asks for confirmation, then cancels the user's registration.
Future<void> cancelWithConfirmation(BuildContext context, AppState appState, Event event) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.ticketCancelConfirmTitle),
      content: Text(l10n.ticketCancelConfirmBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.ticketCancelNo)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.ticketCancelYes)),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await appState.cancelRegistration(event.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.ticketCancelled)));
  } catch (e) {
    final text = (e is PostgrestException && e.message == 'already_checked_in')
        ? l10n.ticketCancelCheckedIn
        : l10n.ticketCancelFailed;
    messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(text)));
  }
}
