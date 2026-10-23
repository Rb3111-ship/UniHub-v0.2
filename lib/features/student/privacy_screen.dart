import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';

/// Explains what is stored and who can see it, and gives the user a copy of their data.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _busy = false;

  Future<void> _export(AppState appState, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final json = await appState.exportMyData();
      await Clipboard.setData(ClipboardData(text: json));
      messenger.showSnackBar(SnackBar(content: Text(l10n.privacyExportDone)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.privacyExportFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.read<AppState>();
    final theme = Theme.of(context);

    Widget section(IconData icon, String title, String body) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(body, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section(Icons.storage_rounded, l10n.privacyWhatTitle, l10n.privacyWhatBody),
          section(Icons.visibility_rounded, l10n.privacyWhoTitle, l10n.privacyWhoBody),
          section(Icons.phone_android_rounded, l10n.privacyLocalTitle, l10n.privacyLocalBody),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : () => _export(appState, l10n),
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.copy_all_rounded),
            label: Text(l10n.privacyExport),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 16),
          Text(l10n.privacyDeleteHint, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
        ],
      ),
    );
  }
}
