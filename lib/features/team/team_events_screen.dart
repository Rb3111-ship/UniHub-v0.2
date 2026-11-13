import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../core/auth/user_role.dart';
import '../../core/models/event_model.dart';
import '../../core/models/team_model.dart';
import '../../core/widgets/page_width.dart';
import '../../core/widgets/ticket_stub.dart';
import '../planner/create_event_screen.dart';

/// The events of an organizer, for a teammate who may create and edit them.
/// Cancelling, publishing again and deleting stay with the organizer.
class TeamEventsScreen extends StatefulWidget {
  const TeamEventsScreen({super.key, required this.team});

  final TeamMembership team;

  @override
  State<TeamEventsScreen> createState() => _TeamEventsScreenState();
}

class _TeamEventsScreenState extends State<TeamEventsScreen> {
  List<Event>? _events;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await context.read<AppState>().loadEventsOf(widget.team.organizerId);
      if (mounted) setState(() => (_events = events, _failed = false));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open({Event? editing}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlannerCreateEventScreen(editing: editing, team: widget.team)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.secondary;
    final locale = Localizations.localeOf(context).toString();
    final events = _events;

    final Widget body;
    if (_failed && events == null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.teamErrGeneric),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: Text(l10n.authRetry)),
        ]),
      );
    } else if (events == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(l10n.teamEventsIntro(widget.team.organizerName), style: TextStyle(fontSize: 13, color: muted)),
            const SizedBox(height: 12),
            if (events.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l10n.teamEventsEmpty))),
            for (final e in events) ...[
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${DateFormat.yMMMEd(locale).add_Hm().format(e.date)}'
                    '${e.status == 'published' ? '' : '  ·  ${e.status.toUpperCase()}'}',
                    style: monoStyle(size: 10.5, color: muted),
                  ),
                  // Only events that are online can be edited by a teammate.
                  trailing: e.status == 'published'
                      ? IconButton(
                          tooltip: l10n.dashboardEdit,
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          onPressed: () => _open(editing: e),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.teamEvents)),
      body: PageWidth(maxWidth: 760, child: body),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.teamNewEvent),
        onPressed: () => _open(),
      ),
    );
  }
}
