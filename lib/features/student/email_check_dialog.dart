import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';

/// The yearly check that a university address still works: a code is sent to
/// the address, and typing it in proves the person can still read that mailbox.
Future<void> showEmailCheckDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _EmailCheckDialog());

class _EmailCheckDialog extends StatefulWidget {
  const _EmailCheckDialog();

  @override
  State<_EmailCheckDialog> createState() => _EmailCheckDialogState();
}

class _EmailCheckDialogState extends State<_EmailCheckDialog> {
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => (_busy = true, _error = null));
    try {
      await context.read<AppState>().sendEmailCheckCode();
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.emailCheckSendFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => (_busy = true, _error = null));
    try {
      await context.read<AppState>().confirmEmailCheck(_code.text);
      navigator.pop();
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text(l10n.emailCheckDone)));
    } catch (_) {
      if (mounted) setState(() => (_busy = false, _error = l10n.emailCheckWrongCode));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final email = context.read<AppState>().accountEmail;
    return AlertDialog(
      title: Text(l10n.emailCheckTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.emailCheckBody(email)),
            if (_sent) ...[
              const SizedBox(height: 12),
              Text(l10n.emailCheckSent, style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: InputDecoration(labelText: l10n.emailCheckCodeHint, border: const OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _code.text.length >= 6 && !_busy ? _confirm() : null,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l10n.profileCancel)),
        if (_sent) TextButton(onPressed: _busy ? null : _send, child: Text(l10n.emailCheckResend)),
        FilledButton(
          onPressed: _busy || (_sent && _code.text.length < 6) ? null : (_sent ? _confirm : _send),
          child: Text(_sent ? l10n.emailCheckConfirm : l10n.emailCheckSend),
        ),
      ],
    );
  }
}
