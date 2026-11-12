import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/models/admin_model.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_width.dart';
import '../../core/widgets/ticket_stub.dart';
import '../student/community_actions.dart' show reportReasonLabel;

/// The record of every suspension, reinstatement, removed event and removed
/// user, with the reports that led to it. This is the proof an admin can show if a decision is questioned.
/// Entries stay even when the event or the account is gone.
class CaseFilesScreen extends StatefulWidget {
  const CaseFilesScreen({super.key});

  @override
  State<CaseFilesScreen> createState() => _CaseFilesScreenState();
}

class _CaseFilesScreenState extends State<CaseFilesScreen> {
  List<ModerationCase>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<AppState>().loadCaseFiles();
      if (mounted) setState(() => (_items = items, _failed = false));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _label(ModerationCase c, AppLocalizations l10n) => switch (c.action) {
        'event_removed' => l10n.caseEventRemoved,
        'user_suspended' => l10n.caseUserSuspended,
        'user_reinstated' => l10n.caseUserReinstated,
        _ => l10n.caseUserRemoved,
      };

  /// The whole case as plain text, for an e-mail or a document.
  String _asText(ModerationCase c, AppLocalizations l10n, String locale) {
    final date = DateFormat.yMMMd(locale).add_Hm();
    final lines = <String>[
      _label(c, l10n),
      '${l10n.caseDecided}: ${date.format(c.createdAt)}${c.decidedBy.isEmpty ? '' : ' (${c.decidedBy})'}',
      '${l10n.caseAbout}: ${c.subjectName}${c.subjectEmail.isEmpty ? '' : ' <${c.subjectEmail}>'}',
      if (c.eventTitle != null) '${l10n.caseEvent}: ${c.eventTitle}',
      if (c.emailBlocked) l10n.caseBlocked,
      if (c.note != null) '${l10n.caseNote}: ${c.note}',
      '',
      l10n.caseReports(c.evidence.length),
      for (final (i, e) in c.evidence.indexed)
        '${i + 1}. ${date.format(e.reportedAt)} · ${e.eventTitle} · ${reportReasonLabel(l10n, e.reason)}'
            '${e.details.isEmpty ? '' : '\n   "${e.details}"'}',
    ];
    return lines.join('\n');
  }

  Future<void> _copy(ModerationCase c) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _asText(c, l10n, Localizations.localeOf(context).toString())));
    messenger.showSnackBar(SnackBar(content: Text(l10n.caseCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final items = _items;

    final Widget body;
    if (_failed && items == null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.adminLoadFailed),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: Text(l10n.authRetry)),
        ]),
      );
    } else if (items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty) {
      body = ListView(children: [
        const SizedBox(height: 40),
        EmptyState(icon: Icons.folder_open_rounded, title: l10n.caseEmpty, body: l10n.caseIntro),
      ]);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Text(l10n.caseIntro, style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary));
            }
            return _caseCard(items[i - 1], l10n, theme, locale);
          },
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: Text(l10n.caseTitle)), body: PageWidth(maxWidth: 820, child: body));
  }

  Widget _caseCard(ModerationCase c, AppLocalizations l10n, ThemeData theme, String locale) {
    final muted = theme.colorScheme.secondary;
    final date = DateFormat.yMMMd(locale).add_Hm();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('case-${c.id}'),
          tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: switch (c.action) {
            'event_removed' => Icon(Icons.event_busy_rounded, color: theme.colorScheme.error),
            'user_suspended' => Icon(Icons.pause_circle_filled_rounded, color: Colors.orange.shade800),
            'user_reinstated' => const Icon(Icons.check_circle_rounded, color: Colors.green),
            _ => Icon(Icons.person_off_rounded, color: theme.colorScheme.error),
          },
          title: Text(
            c.isAboutEvent ? (c.eventTitle ?? '') : (c.subjectName.isEmpty ? c.subjectEmail : c.subjectName),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  _label(c, l10n),
                  if (c.emailBlocked) l10n.caseBlocked,
                  l10n.caseReports(c.evidence.length),
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 2),
              Text(date.format(c.createdAt).toUpperCase(), style: monoStyle(size: 10, color: muted)),
            ],
          ),
          children: [
            _fact(l10n.caseAbout, '${c.subjectName}${c.subjectEmail.isEmpty ? '' : '\n${c.subjectEmail}'}', muted),
            if (c.decidedBy.isNotEmpty) _fact(l10n.caseDecided, c.decidedBy, muted),
            if (c.note != null) _fact(l10n.caseNote, c.note!, muted),
            const SizedBox(height: 10),
            StubSectionHeader(l10n.caseReports(c.evidence.length)),
            const SizedBox(height: 8),
            if (c.evidence.isEmpty) Text(l10n.caseNoReports, style: TextStyle(fontSize: 13, color: muted)),
            for (final e in c.evidence)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.flag_rounded, size: 16, color: Colors.red),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${reportReasonLabel(l10n, e.reason)} · ${e.eventTitle}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          if (e.details.isNotEmpty) Text(e.details, style: const TextStyle(fontSize: 13)),
                          Text(date.format(e.reportedAt).toUpperCase(), style: monoStyle(size: 10, color: muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l10n.caseCopy),
                onPressed: () => _copy(c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fact(String label, String value, Color muted) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: monoStyle(size: 9.5, color: muted, spacing: 1.2)),
            SelectableText(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
