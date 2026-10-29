import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/registration_model.dart';

/// "Are you still coming?" with Yes / I can't come. Shown on the ticket and the
/// event page once the server has asked (about 3 days before the event).
class AttendanceConfirmCard extends StatefulWidget {
  const AttendanceConfirmCard({super.key, required this.registration});

  final Registration registration;

  @override
  State<AttendanceConfirmCard> createState() => _AttendanceConfirmCardState();
}

class _AttendanceConfirmCardState extends State<AttendanceConfirmCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text(done)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.confirmFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final l10n = AppLocalizations.of(context)!;
    final event = widget.registration.event;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmFreeTitle),
        content: Text(l10n.confirmFreeBody(event.title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.profileCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirmFreeAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => context.read<AppState>().cancelRegistration(event.id), l10n.confirmFreed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final event = widget.registration.event;
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline_rounded, color: theme.colorScheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.confirmTitle,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onTertiaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l10n.confirmBody, style: TextStyle(fontSize: 13, color: theme.colorScheme.onTertiaryContainer)),
            if (event.releaseUnconfirmed) ...[
              const SizedBox(height: 6),
              Text(l10n.confirmReleaseWarning,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onTertiaryContainer)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() => context.read<AppState>().confirmAttendance(event.id), l10n.confirmDone),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l10n.confirmYes),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _decline,
                  child: Text(l10n.confirmNo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
