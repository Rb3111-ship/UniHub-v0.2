import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/services/account_repository.dart' show WrongPasswordException;
import 'organizer_application_screen.dart';

/// Account tools shown on the profile page when signed in:
/// edit name, change password, switch view, become an organizer.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    Widget tile(IconData icon, String title, VoidCallback onTap, {String? subtitle}) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: subtitle == null ? null : Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onTap,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile(Icons.badge_outlined, l10n.profileEditName, () => _editName(context, appState, l10n),
            subtitle: appState.activeProfile.name),
        tile(Icons.lock_outline_rounded, l10n.profileChangePassword, () => _changePassword(context, appState, l10n)),
        if (appState.canSwitchView)
          tile(
            Icons.swap_horiz_rounded,
            appState.currentRole == UserRole.student ? l10n.profileSwitchToOrganizer : l10n.profileSwitchToStudent,
            () => appState.setRole(
              appState.currentRole == UserRole.student ? UserRole.planner : UserRole.student,
            ),
          ),
        if (appState.dbRole == 'student') _BecomeOrganizerCard(appState: appState),
      ],
    );
  }

  Future<void> _editName(BuildContext context, AppState appState, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: appState.activeProfile.name);
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileEditName),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: InputDecoration(labelText: l10n.profileNameLabel),
            validator: (v) => (v ?? '').trim().isEmpty ? l10n.authErrNameRequired : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.profileCancel)),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text.trim());
            },
            child: Text(l10n.profileSave),
          ),
        ],
      ),
    );
    // Controllers are left to the garbage collector: the dialog may still be animating closed.
    if (name == null) return;
    try {
      await appState.updateDisplayName(name);
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.authErrGeneric)));
    }
  }

  Future<void> _changePassword(BuildContext context, AppState appState, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final current = TextEditingController();
    final next = TextEditingController();
    final repeat = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileChangePassword),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: current,
                  obscureText: true,
                  autofocus: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(labelText: l10n.passwordCurrent),
                  validator: (v) => (v ?? '').isEmpty ? l10n.passwordWrongCurrent : null,
                ),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(labelText: l10n.authNewPassword),
                  validator: (v) {
                    if ((v ?? '').length < 8) return l10n.authErrPasswordShort;
                    if (v == current.text) return l10n.passwordSameAsOld;
                    return null;
                  },
                ),
                TextFormField(
                  controller: repeat,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(labelText: l10n.passwordRepeat),
                  validator: (v) => v == next.text ? null : l10n.passwordMismatch,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.profileCancel)),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(l10n.profileSave),
          ),
        ],
      ),
    );
    final currentText = current.text;
    final newText = next.text;
    // Controllers are left to the garbage collector: the dialog may still be animating closed.
    if (ok != true) return;
    try {
      await appState.changePassword(currentText, newText);
      messenger.showSnackBar(SnackBar(content: Text(l10n.profilePasswordChanged)));
    } catch (e) {
      final text = e is WrongPasswordException
          ? l10n.passwordWrongCurrent
          : (e is AuthApiException && e.code == 'weak_password')
              ? l10n.authErrPasswordShort
              : l10n.authErrGeneric;
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(text)));
    }
  }
}

class _BecomeOrganizerCard extends StatelessWidget {
  const _BecomeOrganizerCard({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final req = appState.myRequest;

    Widget body;
    if (req != null && req.isPending) {
      body = Text(l10n.organizerStatusPending);
    } else if (req != null && req.status == 'approved') {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.organizerStatusApproved),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              await appState.loadProfile();
              await appState.refreshMyRequest();
            },
            child: Text(l10n.organizerCheckStatus),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (req != null && req.status == 'rejected') ...[
            Text(l10n.organizerStatusRejected, style: TextStyle(color: theme.colorScheme.error)),
            if ((req.reviewNote ?? '').isNotEmpty) Text(req.reviewNote!, style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
          ],
          Text(l10n.organizerBecomeBody, style: TextStyle(color: theme.colorScheme.secondary)),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => _openForm(context), child: Text(l10n.organizerBecomeTitle)),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.campaign_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.organizerBecomeTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 10),
            body,
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const OrganizerApplicationScreen()),
    );
    if (sent == true) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text(l10n.organizerRequestSent)));
    }
  }
}

/// Red "Delete account" button with a type-DELETE confirmation.
class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.read<AppState>();
    return OutlinedButton.icon(
      onPressed: () => _confirmAndDelete(context, appState, l10n),
      icon: const Icon(Icons.delete_forever_rounded),
      label: Text(l10n.profileDeleteAccount),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, AppState appState, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.profileDeleteTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.profileDeleteBody),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: l10n.profileDeleteTypeHint),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.profileCancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: controller.text.trim() == 'DELETE' ? () => Navigator.pop(ctx, true) : null,
              child: Text(l10n.profileDeleteConfirm),
            ),
          ],
        ),
      ),
    );
    // Controllers are left to the garbage collector: the dialog may still be animating closed.
    if (confirmed != true) return;
    try {
      await appState.deleteAccount();
    } catch (e) {
      final text = switch (e is PostgrestException ? e.message : '') {
        'has_events' => l10n.profileDeleteHasEvents,
        'last_admin' => l10n.profileDeleteLastAdmin,
        _ => l10n.profileDeleteFailed,
      };
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(text)));
    }
  }
}
