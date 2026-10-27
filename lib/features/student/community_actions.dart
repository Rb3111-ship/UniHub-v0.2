import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/models/admin_model.dart';
import '../../core/models/event_model.dart';
import 'register_action.dart';

/// Heart button: saves or un-saves an event.
class FavoriteButton extends StatelessWidget {
  final Event event;
  final Color? color;
  final bool onImage; // draws a small dark circle so it stays visible on posters

  const FavoriteButton({super.key, required this.event, this.color, this.onImage = false});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final saved = appState.isFavorite(event.id);
    final button = IconButton(
      tooltip: saved ? l10n.favoriteRemove : l10n.favoriteAdd,
      visualDensity: onImage ? VisualDensity.compact : null,
      icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: saved ? Colors.redAccent : (color ?? Colors.white)),
      onPressed: () => _toggle(context, appState, l10n),
    );
    if (!onImage) return button;
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), shape: BoxShape.circle),
      child: button,
    );
  }

  Future<void> _toggle(BuildContext context, AppState appState, AppLocalizations l10n) async {
    if (appState.isGuest) {
      await askGuestToSignIn(context, appState, l10n.guestSignInTitle, l10n.favoriteGuestBody);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.toggleFavorite(event.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.favoriteFailed)));
    }
  }
}

String reportReasonLabel(AppLocalizations l10n, String reason) => switch (reason) {
      'spam' => l10n.reportReasonSpam,
      'inappropriate' => l10n.reportReasonInappropriate,
      'misleading' => l10n.reportReasonMisleading,
      'scam' => l10n.reportReasonScam,
      _ => l10n.reportReasonOther,
    };

/// Asks why the event should be checked, then sends the report.
Future<void> reportEventDialog(BuildContext context, AppState appState, Event event) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final details = TextEditingController();
  String? reason;
  final send = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l10n.reportTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.reportBody, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              for (final r in EventReport.reasons)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: r,
                  groupValue: reason,
                  onChanged: (v) => setState(() => reason = v),
                  title: Text(reportReasonLabel(l10n, r)),
                ),
              TextField(
                controller: details,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.reportDetails),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.profileCancel)),
          FilledButton(
            onPressed: reason == null ? null : () => Navigator.pop(ctx, true),
            child: Text(l10n.reportSend),
          ),
        ],
      ),
    ),
  );
  final text = details.text.trim();
  // Controllers are left to the garbage collector: the dialog may still be animating closed.
  if (send != true || reason == null) return;
  try {
    await appState.reportEvent(event.id, reason!, text);
    messenger.showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text(l10n.reportSent)));
  } catch (e) {
    final msg = switch (e is PostgrestException ? e.message : '') {
      'already_reported' => l10n.reportAlready,
      'too_many_reports' => l10n.reportTooMany,
      _ => l10n.reportFailed,
    };
    messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(msg)));
  }
}
