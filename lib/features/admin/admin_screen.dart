import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/models/admin_model.dart';
import '../../core/utils/open_link.dart';
import '../student/community_actions.dart' show reportReasonLabel;

/// Approve organizer requests and manage user roles.
/// What each admin may actually do is enforced by the database
/// (university admins: their own university; platform admins: everyone).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load after the first frame: notifying listeners while the tree builds is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      appState.refreshRequests();
      appState.refreshReports();
      appState.refreshUsers('');
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _roleLabel(AppLocalizations l10n, String role) => switch (role) {
        'organizer' => l10n.roleOrganizer,
        'commercial_planner' => l10n.roleCommercial,
        'tenant_admin' => l10n.roleTenantAdmin,
        'platform_admin' => l10n.rolePlatformAdmin,
        _ => l10n.roleStudent,
      };

  Future<void> _review(AppState appState, OrganizerRequest r, bool approve) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${approve ? l10n.adminApprove : l10n.adminReject}: ${r.organizationName}'),
        content: TextField(
          controller: note,
          maxLength: 500,
          maxLines: 2,
          decoration: InputDecoration(hintText: l10n.adminNoteHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.profileCancel)),
          FilledButton(
            style: approve ? null : FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? l10n.adminApprove : l10n.adminReject),
          ),
        ],
      ),
    );
    final text = note.text.trim();
    // Controllers are left to the garbage collector: the dialog may still be animating closed.
    if (ok != true) return;
    try {
      await appState.reviewRequest(r.id, approve, text.isEmpty ? null : text);
      messenger.showSnackBar(SnackBar(content: Text(approve ? l10n.adminRequestApproved : l10n.adminRequestRejected)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.adminActionFailed)));
    }
  }

  /// Opens one of the applicant's documents through a short-lived private link.
  Future<void> _openDocument(AppState appState, String path) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await appState.organizerDocumentUrl(path);
      if (!mounted) return;
      await openLink(context, Uri.parse(url), url);
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.adminDocFailed)));
    }
  }

  Widget _detailLine(IconData icon, String text, ThemeData theme, {VoidCallback? onTap}) {
    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: onTap == null
                  ? const TextStyle(fontSize: 13)
                  : TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: theme.colorScheme.primary)),
        ),
      ]),
    );
    return onTap == null ? line : InkWell(onTap: onTap, child: line);
  }

  Future<void> _resolve(AppState appState, EventReport r, bool remove) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(remove ? l10n.adminRemoveEvent : l10n.adminDismissReport),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(remove ? l10n.adminRemoveEventBody(r.eventTitle) : l10n.adminDismissReportBody),
          if (remove)
            TextField(
              controller: note,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(hintText: l10n.adminRemoveNoteHint),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.profileCancel)),
          FilledButton(
            style: remove ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(remove ? l10n.adminRemoveEvent : l10n.adminDismissReport),
          ),
        ],
      ),
    );
    final text = note.text.trim();
    // Controllers are left to the garbage collector: the dialog may still be animating closed.
    if (ok != true) return;
    try {
      await appState.resolveReport(r.id, remove, text.isEmpty ? null : text);
      messenger.showSnackBar(SnackBar(content: Text(remove ? l10n.adminEventRemoved : l10n.adminReportDismissed)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.adminActionFailed)));
    }
  }

  Widget _reportsList(AppState appState, AppLocalizations l10n, ThemeData theme) {
    final list = appState.eventReports;
    return RefreshIndicator(
      onRefresh: appState.refreshReports,
      child: list.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              Padding(padding: const EdgeInsets.all(48), child: Center(child: Text(l10n.adminNoReports))),
            ])
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _reportCard(appState, list[i], l10n, theme),
            ),
    );
  }

  Widget _reportCard(AppState appState, EventReport r, AppLocalizations l10n, ThemeData theme) {
    final locale = Localizations.localeOf(context).toString();
    // How many open reports the same event has (shown on every card of that event).
    final sameEvent = appState.eventReports.where((x) => x.eventId == r.eventId && x.isOpen).length;
    final (statusText, statusColor) = switch (r.status) {
      'removed' => (l10n.reportStatusRemoved, Colors.red),
      'dismissed' => (l10n.reportStatusDismissed, Colors.grey),
      _ => (l10n.reportStatusOpen, Colors.orange),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(r.eventTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            if (r.eventStart != null)
              Text(DateFormat.yMMMEd(locale).add_Hm().format(r.eventStart!),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.flag_rounded, size: 16, color: Colors.red),
              const SizedBox(width: 6),
              Text(reportReasonLabel(l10n, r.reason), style: const TextStyle(fontWeight: FontWeight.w600)),
              if (r.isOpen && sameEvent > 1) ...[
                const SizedBox(width: 8),
                Text(l10n.adminReportCount(sameEvent), style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
              ],
            ]),
            if (r.details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r.details),
            ],
            Text(DateFormat.yMMMd(locale).add_Hm().format(r.createdAt),
                style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary)),
            if (r.isOpen) ...[
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
                OutlinedButton(onPressed: () => _resolve(appState, r, false), child: Text(l10n.adminDismissReport)),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _resolve(appState, r, true),
                  child: Text(l10n.adminRemoveEvent),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _changeRole(AppState appState, AdminUser u, String role) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.setUserRole(u.id, role, role != 'student', _search.text.trim());
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.adminActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tabAdmin),
          bottom: TabBar(tabs: [
            Tab(text: '${l10n.adminRequests}${appState.pendingRequestCount > 0 ? ' (${appState.pendingRequestCount})' : ''}'),
            Tab(text: '${l10n.adminReports}${appState.openReportCount > 0 ? ' (${appState.openReportCount})' : ''}'),
            Tab(text: l10n.adminUsers),
          ]),
        ),
        body: TabBarView(children: [
          _requests(appState, l10n, theme),
          _reportsList(appState, l10n, theme),
          _users(appState, l10n, theme),
        ]),
      ),
    );
  }

  Widget _requests(AppState appState, AppLocalizations l10n, ThemeData theme) {
    final list = appState.organizerRequests;
    if (appState.adminLoading && list.isEmpty) return const Center(child: CircularProgressIndicator());
    if (appState.adminError && list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.adminLoadFailed),
          const SizedBox(height: 8),
          FilledButton(onPressed: appState.refreshRequests, child: Text(l10n.authRetry)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: appState.refreshRequests,
      child: list.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              Padding(padding: const EdgeInsets.all(48), child: Center(child: Text(l10n.adminNoRequests))),
            ])
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _requestCard(appState, list[i], l10n, theme),
            ),
    );
  }

  Widget _requestCard(AppState appState, OrganizerRequest r, AppLocalizations l10n, ThemeData theme) {
    final statusText = switch (r.status) {
      'approved' => l10n.statusApproved,
      'rejected' => l10n.statusRejected,
      _ => l10n.statusPending,
    };
    final statusColor = switch (r.status) {
      'approved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.orange,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(r.organizationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('${r.displayName}  -  ${r.email}', style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
            Text(r.isCommercial ? l10n.organizerRoleCommercial : l10n.organizerRoleUniversity,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
            const SizedBox(height: 6),
            if ((r.position ?? '').isNotEmpty) _detailLine(Icons.badge_outlined, r.position!, theme),
            if ((r.phone ?? '').isNotEmpty)
              _detailLine(Icons.phone_rounded, r.phone!, theme,
                  onTap: () => openLink(context, Uri(scheme: 'tel', path: r.phone!.replaceAll(RegExp(r'[^0-9+]'), '')), r.phone!)),
            if (r.email.isNotEmpty)
              _detailLine(Icons.mail_outline_rounded, r.email, theme,
                  onTap: () => openLink(context, Uri(scheme: 'mailto', path: r.email), r.email)),
            if ((r.website ?? '').isNotEmpty)
              _detailLine(Icons.language_rounded, r.website!.replaceFirst('https://', ''), theme,
                  onTap: () => openLink(context, Uri.parse(r.website!), r.website!)),
            if (r.isPending && r.phone == null)
              Text(l10n.adminNoVerificationDetails, style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
            if (r.documents.isNotEmpty) ...[
              const SizedBox(height: 6),
              if (r.isPending)
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (var i = 0; i < r.documents.length; i++)
                    ActionChip(
                      avatar: Icon(r.documents[i].endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.image_rounded, size: 18),
                      label: Text(l10n.adminDocument(i + 1)),
                      onPressed: () => _openDocument(appState, r.documents[i]),
                    ),
                ])
              else
                Text(l10n.adminDocsDeleted, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
            ],
            if (r.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.message),
            ],
            if ((r.reviewNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.reviewNote!, style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (r.isPending) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => _review(appState, r, false),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(l10n.adminReject),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => _review(appState, r, true), child: Text(l10n.adminApprove)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _users(AppState appState, AppLocalizations l10n, ThemeData theme) {
    // University admins may only switch people between student and organizer.
    final assignable = appState.isPlatformAdmin
        ? ['student', 'organizer', 'commercial_planner', 'tenant_admin', 'platform_admin']
        : ['student', 'organizer'];
    final users = appState.adminUsers;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l10n.adminSearchHint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: appState.refreshUsers,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => appState.refreshUsers(_search.text.trim()),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final u = users[i];
                final isMe = u.id == appState.currentUserId;
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(u.displayName.isEmpty ? u.email : u.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${u.email}\n${_roleLabel(l10n, u.role)}'),
                    isThreeLine: true,
                    trailing: isMe
                        ? null
                        : PopupMenuButton<String>(
                            tooltip: l10n.adminChangeRole,
                            icon: const Icon(Icons.manage_accounts_rounded),
                            onSelected: (role) => _changeRole(appState, u, role),
                            itemBuilder: (_) => [
                              for (final r in assignable)
                                PopupMenuItem(value: r, enabled: r != u.role, child: Text(_roleLabel(l10n, r))),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
