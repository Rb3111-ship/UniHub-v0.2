import 'package:flutter/material.dart';
import '../../core/widgets/page_width.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/models/admin_model.dart';
import '../../core/utils/open_link.dart';
import '../../core/widgets/ticket_stub.dart';
import '../student/community_actions.dart' show reportReasonLabel;
import 'blocked_emails_screen.dart';
import 'case_files_screen.dart';

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
    // A person can leave the university; an office address (AStA...) stays.
    var permanent = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('${approve ? l10n.adminApprove : l10n.adminReject}: ${r.organizationName}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: note,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(hintText: l10n.adminNoteHint),
            ),
            if (approve && !r.isCommercial)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: permanent,
                onChanged: (v) => setDialog(() => permanent = v ?? false),
                title: Text(l10n.adminPermanentAddress, style: const TextStyle(fontSize: 14)),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.profileCancel)),
            FilledButton(
              style: approve ? null : FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(approve ? l10n.adminApprove : l10n.adminReject),
            ),
          ],
        ),
      ),
    );
    final text = note.text.trim();
    // Controllers are left to the garbage collector: the dialog may still be animating closed.
    if (ok != true) return;
    try {
      await appState.reviewRequest(r.id, approve, text.isEmpty ? null : text, exempt: approve && permanent);
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

  /// Decides all open reports of one event: remove the event, or dismiss them.
  Future<void> _resolve(AppState appState, List<EventReport> open, bool remove) async {
    final r = open.first;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(remove ? l10n.adminRemoveEvent : l10n.adminDismissReport),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(remove
              ? l10n.adminRemoveEventBody(r.eventTitle)
              : (open.length > 1 ? l10n.adminDismissAllBody(open.length) : l10n.adminDismissReportBody)),
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
      if (remove) {
        // Removing the event closes every open report about it in one go.
        await appState.resolveReport(r.id, true, text.isEmpty ? null : text);
      } else {
        for (final x in open) {
          await appState.resolveReport(x.id, false, null);
        }
      }
      messenger.showSnackBar(SnackBar(content: Text(remove ? l10n.adminEventRemoved : l10n.adminReportDismissed)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.adminActionFailed)));
    }
  }

  Widget _reportsList(AppState appState, AppLocalizations l10n, ThemeData theme) {
    final list = appState.eventReports;
    // Stack the reports: organizer -> their reported events -> the single reports.
    final byOrganizer = <String, List<EventReport>>{};
    for (final r in list) {
      byOrganizer.putIfAbsent(r.organizerId ?? 'event:${r.eventId}', () => []).add(r);
    }
    final groups = byOrganizer.values.toList()
      ..sort((a, b) {
        final openA = a.where((r) => r.isOpen).length, openB = b.where((r) => r.isOpen).length;
        return openA != openB ? openB.compareTo(openA) : b.length.compareTo(a.length);
      });
    final caseFiles = Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton.icon(
        icon: const Icon(Icons.folder_copy_outlined, size: 18),
        label: Text(l10n.caseTitle),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaseFilesScreen())),
      ),
    );
    return RefreshIndicator(
      onRefresh: appState.refreshReports,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          caseFiles,
          if (list.isEmpty)
            Padding(padding: const EdgeInsets.all(48), child: Center(child: Text(l10n.adminNoReports))),
          for (final g in groups) ...[
            _organizerReports(appState, g, l10n, theme),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// One organizer with all reports about their events.
  Widget _organizerReports(AppState appState, List<EventReport> reports, AppLocalizations l10n, ThemeData theme) {
    final muted = theme.colorScheme.secondary;
    final name = reports.first.organizerName.isEmpty ? l10n.adminUnknownOrganizer : reports.first.organizerName;
    final byEvent = <String, List<EventReport>>{};
    for (final r in reports) {
      byEvent.putIfAbsent(r.eventId, () => []).add(r);
    }
    final events = byEvent.values.toList()
      ..sort((a, b) => b.where((r) => r.isOpen).length.compareTo(a.where((r) => r.isOpen).length));
    final open = reports.where((r) => r.isOpen).length;
    final organizerId = reports.first.organizerId;
    final isSuspended = reports.first.organizerSuspended;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.person_rounded, size: 20, color: muted),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              if (isSuspended)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(l10n.adminSuspended,
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              if (open > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(l10n.adminOpenCount(open),
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 2),
            Text(l10n.adminReportsSummary(reports.length, events.length).toUpperCase(),
                style: monoStyle(size: 10.5, color: muted, spacing: 0.8)),
            // The reversible step: pause the organizer while the reports are checked.
            if (organizerId != null && organizerId != appState.currentUserId)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  icon: Icon(isSuspended ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded, size: 18),
                  label: Text(isSuspended ? l10n.adminReinstate : l10n.adminSuspendOrganizer),
                  onPressed: () => _setSuspended(appState, organizerId, name, !isSuspended),
                ),
              ),
            for (final e in events) ...[
              const SizedBox(height: 12),
              const DashedRule(),
              const SizedBox(height: 12),
              _eventReports(appState, e, l10n, theme),
            ],
          ],
        ),
      ),
    );
  }

  /// One reported event: its reports, and the two decisions an admin can take.
  Widget _eventReports(AppState appState, List<EventReport> reports, AppLocalizations l10n, ThemeData theme) {
    final locale = Localizations.localeOf(context).toString();
    final muted = theme.colorScheme.secondary;
    final first = reports.first;
    final open = reports.where((r) => r.isOpen).toList();
    final (statusText, statusColor) = open.isNotEmpty
        ? (l10n.reportStatusOpen, Colors.orange)
        : reports.any((r) => r.status == 'removed')
            ? (l10n.reportStatusRemoved, Colors.red)
            : (l10n.reportStatusDismissed, Colors.grey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(first.eventTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
        Text(
          [
            if (first.eventStart != null) DateFormat.yMMMEd(locale).add_Hm().format(first.eventStart!),
            l10n.caseReports(reports.length),
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 8),
        for (final r in reports)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.flag_rounded, size: 16, color: r.isOpen ? Colors.red : muted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reportReasonLabel(l10n, r.reason), style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (r.details.isNotEmpty) Text(r.details),
                      Text(DateFormat.yMMMd(locale).add_Hm().format(r.createdAt).toUpperCase(),
                          style: monoStyle(size: 10, color: muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (open.isNotEmpty)
          Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () => _resolve(appState, open, false), child: Text(l10n.adminDismissReport)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => _resolve(appState, open, true),
              child: Text(l10n.adminRemoveEvent),
            ),
          ]),
      ],
    );
  }

  Future<void> _changeRole(AppState appState, AdminUser u, String role) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.setUserRole(u.id, role, role != 'student', _search.text.trim());
    } catch (e) {
      final noUniversity = e is PostgrestException && e.message == 'needs_university_email';
      messenger.showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text(noUniversity ? l10n.adminNeedsUniversity : l10n.adminActionFailed),
      ));
    }
  }

  static const _removeAction = '_remove';
  static const _suspendAction = '_suspend';
  static const _emailCheckAction = '_emailCheck';

  Future<void> _toggleEmailCheck(AppState appState, AdminUser u) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.setUserEmailCheckExempt(u.id, !u.emailCheckExempt, _search.text.trim());
      messenger.showSnackBar(
          SnackBar(content: Text(u.emailCheckExempt ? l10n.adminYearlyCheckIsOn : l10n.adminYearlyCheckIsOff)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.adminActionFailed)));
    }
  }

  /// Pauses an account while the reports are looked into, or lifts the pause.
  /// Unlike removing, nothing is deleted and it can be undone.
  Future<void> _setSuspended(AppState appState, String userId, String name, bool suspend) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(suspend ? l10n.adminSuspendTitle(name) : l10n.adminReinstateTitle(name)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(suspend ? l10n.adminSuspendBody : l10n.adminReinstateBody),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              maxLength: 500,
              maxLines: 2,
              onChanged: (_) => setDialog(() {}),
              decoration: InputDecoration(hintText: suspend ? l10n.adminSuspendNoteHint : l10n.adminReinstateNoteHint),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.profileCancel)),
            FilledButton(
              style: suspend ? FilledButton.styleFrom(backgroundColor: Colors.orange.shade800) : null,
              // A suspension always needs a written reason: it goes into the case file.
              onPressed: suspend && note.text.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
              child: Text(suspend ? l10n.adminSuspend : l10n.adminReinstate),
            ),
          ],
        ),
      ),
    );
    final text = note.text.trim();
    // Controllers are left to the garbage collector: the dialog may still be animating closed.
    if (ok != true) return;
    try {
      await appState.setUserSuspended(userId, suspend, text.isEmpty ? null : text, _search.text.trim());
      messenger.showSnackBar(
          SnackBar(content: Text(suspend ? l10n.adminUserSuspended(name) : l10n.adminUserReinstated(name))));
    } catch (_) {
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.adminActionFailed)));
    }
  }

  Future<void> _removeUser(AppState appState, AdminUser u) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final name = u.displayName.isEmpty ? u.email : u.displayName;
    var block = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(l10n.adminRemoveUserTitle(name)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u.email, style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.secondary)),
              const SizedBox(height: 12),
              Text(l10n.adminRemoveUserBody),
              if (u.eventCount > 0) ...[
                const SizedBox(height: 8),
                Text(l10n.adminRemoveUserEvents(u.eventCount), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: block,
                onChanged: (v) => setDialog(() => block = v ?? false),
                title: Text(l10n.adminBlockEmail, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.adminRemoveUser),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await appState.removeUser(u.id, block: block, search: _search.text.trim());
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminUserRemoved(name))));
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
        body: PageWidth(maxWidth: 1100, child: TabBarView(children: [
          _requests(appState, l10n, theme),
          _reportsList(appState, l10n, theme),
          _users(appState, l10n, theme),
        ])),
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
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              icon: const Icon(Icons.block_rounded, size: 18),
              label: Text(l10n.adminBlockedTitle),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedEmailsScreen())),
            ),
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
                // Admins must be demoted first; university admins may remove students and organizers.
                final removable = !isMe && !u.isAdmin && (appState.isPlatformAdmin || assignable.contains(u.role));
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(u.displayName.isEmpty ? u.email : u.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text.rich(TextSpan(children: [
                      TextSpan(text: '${u.email}\n${_roleLabel(l10n, u.role)}'),
                      if (!u.emailConfirmed)
                        TextSpan(
                          text: '  ·  ${l10n.adminUnconfirmed}',
                          style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                        ),
                      if (u.emailCheckExempt) TextSpan(text: '  ·  ${l10n.adminNoYearlyCheck}'),
                      if (u.isSuspended)
                        TextSpan(
                          text: '  ·  ${l10n.adminSuspended}',
                          style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700),
                        ),
                    ])),
                    isThreeLine: true,
                    trailing: isMe
                        ? null
                        : PopupMenuButton<String>(
                            tooltip: l10n.adminChangeRole,
                            icon: const Icon(Icons.manage_accounts_rounded),
                            onSelected: (value) => switch (value) {
                              _removeAction => _removeUser(appState, u),
                              _emailCheckAction => _toggleEmailCheck(appState, u),
                              _suspendAction => _setSuspended(
                                  appState, u.id, u.displayName.isEmpty ? u.email : u.displayName, !u.isSuspended),
                              _ => _changeRole(appState, u, value),
                            },
                            itemBuilder: (_) => [
                              for (final r in assignable)
                                // University roles make no sense without a university e-mail.
                                if (u.tenantId != null || (r != 'organizer' && r != 'tenant_admin'))
                                  PopupMenuItem(value: r, enabled: r != u.role, child: Text(_roleLabel(l10n, r))),
                              if (u.tenantId == null)
                                PopupMenuItem(
                                  enabled: false,
                                  height: 36,
                                  child: Text(l10n.adminNeedsUniversity,
                                      style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                                ),
                              // Office addresses (AStA...) can skip the yearly e-mail check.
                              if (u.tenantId != null &&
                                  (u.role == 'organizer' || (u.role == 'tenant_admin' && appState.isPlatformAdmin))) ...[
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: _emailCheckAction,
                                  child: Row(children: [
                                    Icon(u.emailCheckExempt ? Icons.mark_email_read_outlined : Icons.unsubscribe_outlined,
                                        size: 20),
                                    const SizedBox(width: 10),
                                    Flexible(
                                        child: Text(u.emailCheckExempt ? l10n.adminYearlyCheckOn : l10n.adminYearlyCheckOff)),
                                  ]),
                                ),
                              ],
                              if (removable) ...[
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: _suspendAction,
                                  child: Row(children: [
                                    Icon(u.isSuspended ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                                        size: 20),
                                    const SizedBox(width: 10),
                                    Text(u.isSuspended ? l10n.adminReinstate : l10n.adminSuspend),
                                  ]),
                                ),
                                PopupMenuItem(
                                  value: _removeAction,
                                  child: Row(children: [
                                    Icon(Icons.person_remove_rounded, color: theme.colorScheme.error, size: 20),
                                    const SizedBox(width: 10),
                                    Text(l10n.adminRemoveUser, style: TextStyle(color: theme.colorScheme.error)),
                                  ]),
                                ),
                              ],
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
