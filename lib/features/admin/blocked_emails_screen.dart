import 'package:flutter/material.dart';
import '../../core/widgets/page_width.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/models/admin_model.dart';
import '../../core/widgets/empty_state.dart';

/// Addresses an admin blocked from signing up, each with an Unblock button.
class BlockedEmailsScreen extends StatefulWidget {
  const BlockedEmailsScreen({super.key});

  @override
  State<BlockedEmailsScreen> createState() => _BlockedEmailsScreenState();
}

class _BlockedEmailsScreenState extends State<BlockedEmailsScreen> {
  List<BlockedEmail>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<AppState>().loadBlockedEmails();
      if (mounted) setState(() => (_items = items, _failed = false));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _unblock(BlockedEmail b) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminUnblockTitle),
        content: Text(l10n.adminUnblockBody(b.email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.adminUnblock)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await appState.unblockEmail(b.email);
      setState(() => _items = [for (final x in _items ?? <BlockedEmail>[]) if (x.email != b.email) x]);
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminUnblocked(b.email))));
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.adminActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final items = _items;
    final dateFormat = DateFormat.yMMMd(l10n.localeName);

    Widget body;
    if (items == null && !_failed) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items == null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.adminLoadFailed),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: Text(l10n.authRetry)),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: items.isEmpty
            ? ListView(children: [
                const SizedBox(height: 40),
                EmptyState(icon: Icons.block_rounded, title: l10n.adminNoBlocked),
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Text(l10n.adminBlockedHint, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary));
                  }
                  final b = items[i - 1];
                  final who = b.blockedBy == null ? '' : ' · ${b.blockedBy}';
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(Icons.block_rounded, color: theme.colorScheme.error),
                      title: Text(b.email, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${dateFormat.format(b.blockedAt)}$who'),
                      trailing: TextButton(onPressed: () => _unblock(b), child: Text(l10n.adminUnblock)),
                    ),
                  );
                },
              ),
      );
    }
    return Scaffold(appBar: AppBar(title: Text(l10n.adminBlockedTitle)), body: PageWidth(maxWidth: 760, child: body));
  }
}
