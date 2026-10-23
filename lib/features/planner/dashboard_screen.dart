import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/review_model.dart';
import '../../../core/models/dashboard_model.dart';
import 'create_event_screen.dart';

class PlannerDashboardScreen extends StatelessWidget {
  const PlannerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: appState.refreshDashboard,
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appState.getTenantDisplayName(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  localizations.plannerDashboardTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                appState.usesBackend
                    ? _realSections(context, appState, localizations)
                    : _mockSections(context, appState, localizations),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }


  List<Widget> _mockSections(BuildContext context, AppState appState, AppLocalizations localizations) {
    return [
                  _buildQuickStats(context, appState, localizations),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, "Attendance By Event"),
                  const SizedBox(height: 12),
                  _buildEventStatusRow(
                    context,
                    title: localizations.mockEventTitle,
                    ticketsSold: 184,
                    totalCapacity: 250,
                    percent: 0.73,
                    color: const Color(0xFF636AE8),
                  ),
                  const SizedBox(height: 12),
                  _buildEventStatusRow(
                    context,
                    title: "Summer BBQ Party",
                    ticketsSold: 92,
                    totalCapacity: 100,
                    percent: 0.92,
                    color: const Color(0xFF03DAC5),
                  ),
                  const SizedBox(height: 12),
                  _buildEventStatusRow(
                    context,
                    title: "Graduation Gala",
                    ticketsSold: 412,
                    totalCapacity: 500,
                    percent: 0.82,
                    color: const Color(0xFFF15A24),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, "Recent Scanner Logs"),
                  const SizedBox(height: 12),
                  _buildLogTile(context, "Student Alex Smith scanned ticket for concert", "2 mins ago", true),
                  _buildLogTile(context, "Student Jessica Miller ticket verified", "5 mins ago", true),
                  _buildLogTile(context, "Invalid Ticket Code detected (Device 02)", "12 mins ago", false),
                  const SizedBox(height: 28),
                  _buildFeedbackSection(context, appState, localizations),
                  const SizedBox(height: 40),
    ];
  }

  List<Widget> _realSections(BuildContext context, AppState appState, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final d = appState.dashboard;
    if (appState.dashboardLoading && d.stats.isEmpty) {
      return [const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))];
    }
    if (appState.dashboardError && d.stats.isEmpty) {
      return [
        const SizedBox(height: 80),
        Center(child: Text(l10n.dashboardLoadFailed)),
        const SizedBox(height: 12),
        Center(child: FilledButton(onPressed: appState.refreshDashboard, child: Text(l10n.authRetry))),
      ];
    }
    return [
      _buildQuickStats(context, appState, l10n),
      const SizedBox(height: 24),
      _buildSectionTitle(context, l10n.dashboardAttendanceByEvent),
      const SizedBox(height: 12),
      if (d.stats.isEmpty)
        _buildEmptyFeedback(theme, l10n.dashboardNoEventsYet)
      else
        for (final stat in d.stats.take(20)) ...[
          _buildRealEventRow(context, stat, l10n),
          const SizedBox(height: 12),
        ],
      const SizedBox(height: 12),
      _buildSectionTitle(context, l10n.dashboardRecentScans),
      const SizedBox(height: 12),
      if (d.scans.isEmpty)
        _buildEmptyFeedback(theme, l10n.scanLogEmpty)
      else
        for (final e in d.scans) _buildLogTile(context, _scanText(e, l10n), _ago(e.scannedAt, l10n), e.ok),
      const SizedBox(height: 28),
      _buildFeedbackSection(context, appState, l10n),
      const SizedBox(height: 40),
    ];
  }

  String _scanText(ScanEntry e, AppLocalizations l10n) {
    final ticket = e.ticketDisplayId.isEmpty ? 'Ticket' : e.ticketDisplayId;
    final text = switch (e.result) {
      'granted' => l10n.scanLogGranted(ticket),
      'already_used' => l10n.scanLogAlreadyUsed(ticket),
      'wrong_event' => l10n.scanLogWrongEvent(ticket),
      'cancelled' => l10n.scanLogCancelled(ticket),
      _ => l10n.scanLogInvalid,
    };
    return e.eventTitle.isEmpty ? text : '$text - ${e.eventTitle}';
  }

  String _ago(DateTime time, AppLocalizations l10n) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return l10n.agoJustNow;
    if (diff.inMinutes < 60) return l10n.agoMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.agoHours(diff.inHours);
    return l10n.agoDays(diff.inDays);
  }

  Widget _buildRealEventRow(BuildContext context, EventStat stat, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final detail = stat.capacity == null
        ? l10n.dashboardUnlimitedLine(stat.registered, stat.checkedIn)
        : l10n.dashboardSeatsLine(stat.registered, stat.capacity!, stat.checkedIn);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (stat.status != 'cancelled' && context.read<AppState>().managedEventById(stat.eventId) != null)
                  IconButton(
                    tooltip: l10n.dashboardEdit,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlannerCreateEventScreen(
                          editing: context.read<AppState>().managedEventById(stat.eventId),
                        ),
                      ),
                    ),
                  ),
                if (stat.status != 'published')
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(stat.status.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                if (stat.averageRating != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade700),
                  Text(' ${stat.averageRating!.toStringAsFixed(1)} (${stat.reviewCount})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(detail, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
            if (stat.waitlisted > 0)
              Text(l10n.dashboardWaitlistCount(stat.waitlisted),
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stat.fillShare,
                minHeight: 8,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, AppState appState, AppLocalizations localizations) {
    final real = appState.usesBackend;
    final d = appState.dashboard;
    final rsvps = real ? d.totalRegistered : appState.totalRsvps;
    final checkIns = real ? d.totalCheckedIn : appState.totalCheckIns;
    final rate = real ? d.attendanceRate : appState.attendanceRate;
    final activeEvents = real ? d.activeEvents : appState.events.length;
    final attendanceRateStr = "${rate.toStringAsFixed(1)}%";
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildStatCard(context, localizations.dashboardTotalRsvps, rsvps.toString(), Icons.confirmation_number_rounded, const Color(0xFF636AE8)),
            _buildStatCard(context, localizations.dashboardTotalCheckins, checkIns.toString(), Icons.qr_code_scanner_rounded, const Color(0xFFF15A24)),
            _buildStatCard(context, localizations.dashboardAttendanceRate, attendanceRateStr, Icons.trending_up_rounded, const Color(0xFF03DAC5)),
            _buildStatCard(context, localizations.dashboardActiveEvents, activeEvents.toString(), Icons.event_available_rounded, Colors.purple),
          ],
        );
      },
    );
  }

  Widget _buildFeedbackSection(BuildContext context, AppState appState, AppLocalizations localizations) {
    final theme = Theme.of(context);
    final items = appState.usesBackend
        ? appState.feedback
        : appState.reviews
            .map((r) => (
                  review: r,
                  eventTitle: appState.events.where((e) => e.id == r.eventId).map((e) => e.title).firstOrNull ?? '',
                ))
            .toList();
    final publicReviews = items.where((f) => f.review.isVerified).toList();
    final privateReviews = items.where((f) => !f.review.isVerified).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, localizations.dashboardPublicRatings),
        const SizedBox(height: 12),
        if (publicReviews.isEmpty)
          _buildEmptyFeedback(theme, localizations.dashboardNoPublicRatings)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: publicReviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final item = publicReviews[idx];
              return _buildPublicReviewCard(context, item.review, item.eventTitle, theme, localizations);
            },
          ),
        const SizedBox(height: 28),
        _buildSectionTitle(context, localizations.dashboardPrivateFeedback),
        const SizedBox(height: 12),
        // Warning disclaimer banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.errorContainer.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.reviewWarningDisclaimer,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (privateReviews.isEmpty)
          _buildEmptyFeedback(theme, localizations.dashboardNoPrivateFeedback)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: privateReviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final item = privateReviews[idx];
              return _buildPrivateFeedbackCard(context, item.review, item.eventTitle, theme, localizations);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyFeedback(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildPublicReviewCard(
    BuildContext context,
    Review review,
    String eventTitle,
    ThemeData theme,
    AppLocalizations localizations,
  ) {
    final formattedDate = "${review.timestamp.day}.${review.timestamp.month}.${review.timestamp.year}";
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    eventTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        localizations.reviewVerifiedLabel,
                        style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber.shade700,
                      size: 16,
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: TextStyle(color: theme.colorScheme.secondary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateFeedbackCard(
    BuildContext context,
    Review review,
    String eventTitle,
    ThemeData theme,
    AppLocalizations localizations,
  ) {
    final formattedDate = "${review.timestamp.day}.${review.timestamp.month}.${review.timestamp.year}";
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    eventTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    localizations.reviewUnverifiedLabel,
                    style: TextStyle(color: theme.colorScheme.secondary, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber.shade700,
                      size: 16,
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: TextStyle(color: theme.colorScheme.secondary, fontSize: 11),
                ),
                const Spacer(),
                if (review.claimedAttendance)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(localizations.dashboardClaimedAttendance, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(icon, color: color.withOpacity(0.8), size: 20),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }

  Widget _buildEventStatusRow(
    BuildContext context, {
    required String title,
    required int ticketsSold,
    required int totalCapacity,
    required double percent,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  "$ticketsSold/$totalCapacity Sold",
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 8,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTile(BuildContext context, String title, String time, bool isSuccess) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: isSuccess ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
            child: Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isSuccess ? Colors.green : Colors.red,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            time,
            style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary),
          ),
        ],
      ),
    );
  }
}
