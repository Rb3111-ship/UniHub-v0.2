import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/review_model.dart';
import '../../../core/models/event_model.dart';

class PlannerDashboardScreen extends StatelessWidget {
  const PlannerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    return Scaffold(
      body: CustomScrollView(
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
                [
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, AppState appState, AppLocalizations localizations) {
    final attendanceRateStr = "${appState.attendanceRate.toStringAsFixed(1)}%";
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
            _buildStatCard(context, localizations.dashboardTotalRsvps, appState.totalRsvps.toString(), Icons.confirmation_number_rounded, const Color(0xFF636AE8)),
            _buildStatCard(context, localizations.dashboardTotalCheckins, appState.totalCheckIns.toString(), Icons.qr_code_scanner_rounded, const Color(0xFFF15A24)),
            _buildStatCard(context, localizations.dashboardAttendanceRate, attendanceRateStr, Icons.trending_up_rounded, const Color(0xFF03DAC5)),
            _buildStatCard(context, "Active Events", appState.events.length.toString(), Icons.event_available_rounded, Colors.purple),
          ],
        );
      },
    );
  }

  Widget _buildFeedbackSection(BuildContext context, AppState appState, AppLocalizations localizations) {
    final theme = Theme.of(context);
    final allReviews = appState.reviews;
    final publicReviews = allReviews.where((r) => r.isVerified).toList();
    final privateReviews = allReviews.where((r) => !r.isVerified).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, localizations.dashboardPublicRatings),
        const SizedBox(height: 12),
        if (publicReviews.isEmpty)
          _buildEmptyFeedback(theme, "No public ratings yet.")
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: publicReviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final review = publicReviews[idx];
              final event = appState.events.firstWhere((e) => e.id == review.eventId, orElse: () => appState.events.first);
              return _buildPublicReviewCard(context, review, event, theme, localizations);
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
          _buildEmptyFeedback(theme, "No private feedback yet.")
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: privateReviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final review = privateReviews[idx];
              final event = appState.events.firstWhere((e) => e.id == review.eventId, orElse: () => appState.events.first);
              return _buildPrivateFeedbackCard(context, review, event, theme, localizations);
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
    Event event,
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
                    event.title,
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
    Event event,
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
                    event.title,
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
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text("Claimed Attendance", style: TextStyle(fontSize: 10, color: Colors.grey)),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                Icon(icon, color: color.withOpacity(0.8), size: 20),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
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
