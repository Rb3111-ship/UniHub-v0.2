import 'package:flutter/material.dart';
import '../../core/widgets/page_width.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/widgets/ticket_stub.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/dashboard_model.dart';
import 'charts.dart';

const registeredColor = Color(0xFF636AE8);
const confirmedColor = Color(0xFF03A99A);
const cameColor = Color(0xFFF15A24);

/// Statistics of one event: attendance, the "still coming?" answers, sign-ups
/// per day and how many stars people gave.
class EventInsightsScreen extends StatefulWidget {
  const EventInsightsScreen({super.key, required this.stat});

  final EventStat stat;

  @override
  State<EventInsightsScreen> createState() => _EventInsightsScreenState();
}

class _EventInsightsScreenState extends State<EventInsightsScreen> {
  EventInsights? _insights;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    try {
      final insights = await appState.loadEventInsights(widget.stat.eventId);
      if (mounted) setState(() => (_insights = insights, _failed = false));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([context.read<AppState>().refreshDashboard(), _load()]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    // Use the freshest numbers after a refresh.
    final stat = appState.dashboard.stats.where((s) => s.eventId == widget.stat.eventId).firstOrNull ?? widget.stat;
    final insights = _insights;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.insightsTitle)),
      body: PageWidth(maxWidth: 900, child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(stat.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(
              DateFormat.yMMMEd(l10n.localeName).add_Hm().format(stat.startsAt),
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: 16),
            _tiles(context, stat, l10n),
            const SizedBox(height: 16),
            _section(context, l10n.insightsAttendance, [
              ..._attendanceBars(stat, l10n),
              if (!stat.requiresQr) ...[
                const SizedBox(height: 8),
                Text(l10n.insightsCameUnknown, style: const TextStyle(fontSize: 12)),
              ],
            ]),
            if (_failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  Text(l10n.dashboardLoadFailed),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _load, child: Text(l10n.authRetry)),
                ]),
              )
            else if (insights == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else ...[
              _section(context, l10n.insightsConfirmation, [
                Text(
                  insights.asked == 0
                      ? l10n.insightsNotAskedYet
                      : l10n.insightsConfirmationLine(insights.asked, stat.confirmed, insights.declined, stat.released),
                  style: const TextStyle(fontSize: 13),
                ),
              ]),
              _section(context, l10n.insightsSignups, [
                if (insights.signupsPerDay.isEmpty) Text(l10n.insightsNoSignups) else _signupChart(context, insights),
              ]),
              _section(context, l10n.insightsStars, [
                if (insights.reviewCount == 0)
                  Text(l10n.insightsNoRatings)
                else ...[
                  Text(
                    l10n.insightsAverage(insights.averageStars!.toStringAsFixed(1), insights.reviewCount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(l10n.insightsVerifiedNote(insights.verifiedReviews), style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 10),
                  for (var star = 5; star >= 1; star--)
                    HBar(
                      label: '$star★',
                      value: insights.stars[star - 1],
                      max: insights.stars.reduce((a, b) => a > b ? a : b),
                      color: Colors.amber.shade700,
                    ),
                ],
              ]),
            ],
            const SizedBox(height: 32),
          ],
        ),
      )),
    );
  }

  List<Widget> _attendanceBars(EventStat stat, AppLocalizations l10n) {
    final max = stat.capacity ?? stat.registered;
    return [
      HBar(label: l10n.legendRegistered, labelWidth: 96, value: stat.registered, max: max, color: registeredColor, height: 14),
      HBar(label: l10n.legendConfirmed, labelWidth: 96, value: stat.confirmed, max: max, color: confirmedColor, height: 14),
      if (stat.requiresQr)
        HBar(label: l10n.legendCame, labelWidth: 96, value: stat.checkedIn, max: max, color: cameColor, height: 14),
    ];
  }

  Widget _tiles(BuildContext context, EventStat stat, AppLocalizations l10n) {
    final noShow = stat.noShowShare;
    final tiles = <(String, String, Color)>[
      (l10n.legendRegistered, stat.capacity == null ? '${stat.registered}' : '${stat.registered}/${stat.capacity}', registeredColor),
      (l10n.legendConfirmed, '${stat.confirmed}', confirmedColor),
      if (stat.requiresQr) (l10n.legendCame, '${stat.checkedIn}', cameColor),
      if (noShow != null) (l10n.statNoShow, '${(noShow * 100).round()}%', Colors.red.shade400),
      (l10n.statWaitlist, '${stat.waitlisted}', Colors.orange.shade700),
      (l10n.statCancelled, '${stat.cancelled}', Colors.grey.shade600),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, value, color) in tiles)
          SizedBox(
            width: 104,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Bars for every day from the first sign-up to the last (at most 30 days).
  Widget _signupChart(BuildContext context, EventInsights insights) {
    final days = insights.signupsPerDay.keys.toList()..sort();
    var first = days.first;
    final last = days.last;
    if (last.difference(first).inDays > 29) first = last.subtract(const Duration(days: 29));
    final values = <double>[];
    final labels = <String>[];
    final count = last.difference(first).inDays + 1;
    final every = count <= 10 ? 1 : (count / 6).ceil();
    for (var i = 0; i < count; i++) {
      final day = DateTime(first.year, first.month, first.day + i);
      values.add((insights.signupsPerDay[day] ?? 0).toDouble());
      labels.add(i % every == 0 || i == count - 1 ? DateFormat('d.M.').format(day) : '');
    }
    return VBars(values: values, labels: labels, color: registeredColor);
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StubSectionHeader(title),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
