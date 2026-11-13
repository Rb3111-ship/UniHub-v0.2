import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/models/team_model.dart';
import '../../core/widgets/page_width.dart';
import '../../core/widgets/ticket_stub.dart';
import '../planner/qr_scanner_screen.dart';
import 'team_events_screen.dart';

/// Everything about teams in one place:
///  * organizers invite helpers and decide what each may do
///  * helpers answer invitations and start scanning / editing from here
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _email = TextEditingController();
  bool _inviteScan = true;
  bool _inviteEdit = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().refreshTeams();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  /// Runs a team action and shows [done] or a fitting error.
  Future<void> _run(Future<void> Function() action, String? done) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      final text = switch (e is PostgrestException ? e.message : '') {
        'team_full' => l10n.teamErrFull,
        'already_in_team' => l10n.teamErrAlready,
        'cannot_invite_self' => l10n.teamErrSelf,
        'needs_permission' => l10n.teamErrNeedsPermission,
        _ => l10n.teamErrGeneric,
      };
      messenger.showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite(AppState appState, AppLocalizations l10n) async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(l10n.authErrInvalidEmail)));
      return;
    }
    await _run(() async {
      await appState.inviteTeammate(email, canScan: _inviteScan, canEdit: _inviteEdit);
      _email.clear();
    }, l10n.teamInviteSent);
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.profileCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  String _rights(AppLocalizations l10n, bool scan, bool edit) =>
      [if (scan) l10n.teamCanScan, if (edit) l10n.teamCanEdit].join(' · ');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.secondary;
    final members = appState.teamMembers;
    final memberships = appState.teamMemberships;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.teamTitle)),
      body: PageWidth(
        maxWidth: 760,
        child: RefreshIndicator(
          onRefresh: appState.refreshTeams,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // ---------------------------------------------------- the organizer's own team
              if (appState.canHaveTeam) ...[
                StubSectionHeader(l10n.teamMineTitle),
                const SizedBox(height: 8),
                Text(l10n.teamMineIntro, style: TextStyle(fontSize: 13, color: muted)),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.teamInviteTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: l10n.teamInviteEmail,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _inviteScan,
                          onChanged: (v) => setState(() => _inviteScan = v ?? false),
                          title: Text(l10n.teamCanScan),
                          subtitle: Text(l10n.teamCanScanHint, style: const TextStyle(fontSize: 12)),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _inviteEdit,
                          onChanged: (v) => setState(() => _inviteEdit = v ?? false),
                          title: Text(l10n.teamCanEdit),
                          subtitle: Text(l10n.teamCanEditHint, style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: Text(l10n.teamInviteSend),
                            onPressed:
                                _busy || !(_inviteScan || _inviteEdit) ? null : () => _invite(appState, l10n),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.teamCount(members.length).toUpperCase(), style: monoStyle(size: 10.5, color: muted, spacing: 0.8)),
                const SizedBox(height: 8),
                if (members.isEmpty) Text(l10n.teamMineEmpty, style: TextStyle(color: muted)),
                for (final m in members) ...[_memberCard(appState, m, l10n, theme), const SizedBox(height: 8)],
                const SizedBox(height: 20),
              ],

              // ---------------------------------------------------- teams this person helps
              StubSectionHeader(l10n.teamHelpTitle),
              const SizedBox(height: 8),
              if (memberships.isEmpty) Text(l10n.teamHelpEmpty, style: TextStyle(color: muted)),
              for (final m in memberships) ...[_membershipCard(appState, m, l10n, theme), const SizedBox(height: 8)],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberCard(AppState appState, TeamMember m, AppLocalizations l10n, ThemeData theme) {
    final muted = theme.colorScheme.secondary;
    final name = m.name.isEmpty ? m.email : m.name;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              if (!m.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(l10n.teamInvited,
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              IconButton(
                tooltip: m.isActive ? l10n.teamRemove : l10n.teamWithdraw,
                icon: Icon(Icons.person_remove_rounded, color: theme.colorScheme.error, size: 20),
                onPressed: _busy
                    ? null
                    : () async {
                        if (!await _confirm(l10n.teamRemoveTitle(name), l10n.teamRemoveBody, l10n.teamRemove)) return;
                        await _run(() => appState.removeFromTeam(m.id), l10n.teamRemoved);
                      },
              ),
            ]),
            Text(m.email, style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              FilterChip(
                label: Text(l10n.teamCanScan),
                selected: m.canScan,
                // The last remaining permission cannot be switched off (remove the person instead).
                onSelected: _busy || (m.canScan && !m.canEdit)
                    ? null
                    : (v) => _run(() => appState.setTeamPermissions(m.id, canScan: v, canEdit: m.canEdit), null),
              ),
              FilterChip(
                label: Text(l10n.teamCanEdit),
                selected: m.canEdit,
                onSelected: _busy || (m.canEdit && !m.canScan)
                    ? null
                    : (v) => _run(() => appState.setTeamPermissions(m.id, canScan: m.canScan, canEdit: v), null),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _membershipCard(AppState appState, TeamMembership m, AppLocalizations l10n, ThemeData theme) {
    final muted = theme.colorScheme.secondary;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.organizerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(_rights(l10n, m.canScan, m.canEdit).toUpperCase(), style: monoStyle(size: 10.5, color: muted, spacing: 0.8)),
            const SizedBox(height: 10),
            if (!m.isActive) ...[
              Text(l10n.teamInvitationBody(m.organizerName)),
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(() => appState.answerTeamInvite(m.id, false), l10n.teamDeclined),
                  child: Text(l10n.teamDecline),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _run(() => appState.answerTeamInvite(m.id, true), l10n.teamAccepted),
                  child: Text(l10n.teamAccept),
                ),
              ]),
            ] else ...[
              if (!m.usable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l10n.teamPaused, style: TextStyle(color: Colors.orange.shade800, fontSize: 13)),
                ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (m.canScan)
                  FilledButton.icon(
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: Text(l10n.teamScan),
                    onPressed: !m.usable
                        ? null
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlannerScannerScreen(team: m))),
                  ),
                if (m.canEdit)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                    label: Text(l10n.teamEvents),
                    onPressed: !m.usable
                        ? null
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeamEventsScreen(team: m))),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (!await _confirm(l10n.teamLeaveTitle(m.organizerName), l10n.teamLeaveBody, l10n.teamLeave)) {
                            return;
                          }
                          await _run(() => appState.removeFromTeam(m.id), l10n.teamLeft);
                        },
                  child: Text(l10n.teamLeave),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
