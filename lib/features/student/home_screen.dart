import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/categories.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/event_search.dart';
import '../../../core/widgets/event_image.dart';
import 'details_screen.dart';
import 'register_action.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _searchController.clear();
    });
  }

  /// "Other" opens a short list: everything else, or one of the (at most 15)
  /// most used categories organizers typed in themselves.
  Future<void> _showOtherCategories(AppState appState, AppLocalizations l10n) async {
    final top = topCustomCategories(appState.events.map((e) => e.categories));
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final selected = appState.selectedCategory;
        Widget option(String key, String label, IconData icon, {int? count}) {
          final isSelected = selected.toLowerCase() == key.toLowerCase();
          return ListTile(
            leading: Icon(icon, color: isSelected ? appState.getActiveTenantColor() : null),
            title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            trailing: count == null
                ? null
                : Text('$count', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
            selected: isSelected,
            onTap: () => Navigator.pop(ctx, key),
          );
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(l10n.otherCategoriesTitle, style: theme.textTheme.titleMedium),
                ),
                option('Other', l10n.otherCategoriesAll, Icons.more_horiz_rounded),
                if (top.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.otherCategoriesEmpty, style: TextStyle(color: theme.colorScheme.secondary)),
                  )
                else
                  for (final c in top) option(c.name, c.name, Icons.label_rounded, count: c.count),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) appState.setSelectedCategory(picked);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    final selected = appState.selectedCategory;
    final customSelected = selected != 'All' && !isStandardCategory(selected);
    // The fixed category chips. "Other" shows the chosen custom category, if any.
    final categories = [
      {'key': 'All', 'label': localizations.categoryAll, 'icon': Icons.grid_view_rounded},
      {'key': 'Music', 'label': localizations.categoryMusic, 'icon': Icons.music_note_rounded},
      {'key': 'Tech', 'label': localizations.categoryTech, 'icon': Icons.code_rounded},
      {'key': 'Sports', 'label': localizations.categorySports, 'icon': Icons.sports_soccer_rounded},
      {'key': 'Arts', 'label': localizations.categoryArts, 'icon': Icons.palette_rounded},
      {'key': 'Academic', 'label': localizations.categoryAcademic, 'icon': Icons.menu_book_rounded},
      {
        'key': 'Other',
        'label': customSelected ? '${localizations.categoryOther}: $selected' : localizations.categoryOther,
        'icon': Icons.expand_more_rounded,
      },
    ];

    // Category filter, then the search box (title, category, organizer, place).
    final query = _searchController.text;
    final filteredEvents = appState.events
        .where((e) => matchesCategory(e.categories, selected))
        .where((e) => matchesSearch(e, query, appState.hostOf(e.organizerId), localizations))
        .toList();

    // Split events by official status
    final campusEvents = filteredEvents.where((e) => e.isUniversityOfficial).toList();
    final publicEvents = filteredEvents.where((e) => !e.isUniversityOfficial).toList();
    // Signed-out visitors only ever get public events, so they see a single feed.
    final guest = appState.isGuest;

    final titleWidget = _searching
        ? TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: localizations.searchHint,
              border: InputBorder.none,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!guest)
                Text(
                  appState.getTenantDisplayName(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: appState.getActiveTenantColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                guest ? localizations.guestFeedTitle : localizations.studentHomeTitle,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: titleWidget,
          actions: [
            IconButton(
              tooltip: _searching ? localizations.searchClose : localizations.searchOpen,
              icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
              onPressed: _searching ? _closeSearch : () => setState(() => _searching = true),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(guest ? 52 : 108),
            child: Column(
              children: [
                // Category Selector Row
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final key = cat['key'] as String;
                      final isSelected = key == 'Other' ? (selected == 'Other' || customSelected) : selected == key;
                      final activeColor = appState.getActiveTenantColor();

                      return ChoiceChip(
                        showCheckmark: false,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat['icon'] as IconData,
                              size: 16,
                              color: isSelected ? Colors.white : activeColor,
                            ),
                            const SizedBox(width: 6),
                            Text(cat['label'] as String),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: activeColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.85),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          if (key == 'Other') {
                            _showOtherCategories(appState, localizations);
                          } else {
                            appState.setSelectedCategory(key);
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Main Feeds TabBar
                if (!guest)
                  TabBar(
                    indicatorColor: appState.getActiveTenantColor(),
                    labelColor: appState.getActiveTenantColor(),
                    unselectedLabelColor: Colors.grey,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.school_rounded, size: 18),
                            const SizedBox(width: 8),
                            Flexible(child: Text(localizations.tabCampusHub, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.public_rounded, size: 18),
                            const SizedBox(width: 8),
                            Flexible(child: Text(localizations.tabPublicEvents, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        // The wallpaper is painted behind this screen by the surrounding WallpaperArea.
        body: guest
            ? _buildEventGrid(context, publicEvents, false, appState)
            : TabBarView(
                children: [
                  // Feed 1: Campus Hub (University Official)
                  _buildEventGrid(context, campusEvents, true, appState),
                  // Feed 2: Public Events (Commercial/Public)
                  _buildEventGrid(context, publicEvents, false, appState),
                ],
              ),
      ),
    );
  }

  Widget _buildEventGrid(
    BuildContext context,
    List<Event> events,
    bool isOfficialFeed,
    AppState appState,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (appState.eventsLoading && appState.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (appState.eventsError && appState.events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.eventsLoadFailed),
            const SizedBox(height: 12),
            FilledButton(onPressed: appState.refreshEvents, child: Text(l10n.authRetry)),
          ],
        ),
      );
    }
    if (events.isEmpty) {
      return RefreshIndicator(
        onRefresh: appState.refreshEvents,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 320,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    _searchController.text.trim().isNotEmpty ? l10n.searchNoResults : l10n.eventsEmptyCategory,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    // Responsive grid layout column configurations
    final crossAxisCount = screenWidth >= 1100 ? 3 : (screenWidth >= 700 ? 2 : 1);

    return RefreshIndicator(
      onRefresh: appState.refreshEvents,
      child: GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: screenWidth >= 500 ? 1.25 : 1.35,
      ),
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildEventTile(context, event, isOfficialFeed, appState);
      },
    ));
  }

  Widget _buildEventTile(
    BuildContext context,
    Event event,
    bool isOfficialFeed,
    AppState appState,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic brand color
    final universityColor = appState.getUniversityColor(event.universityDomain);
    final isMatchingDomain = event.universityDomain == appState.getTenantDomain();

    final dateBadgeMonth = _getMonthAbbreviation(event.date);
    final dateBadgeDay = event.date.day.toString();

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withOpacity(isDark ? 0.65 : 0.85) ??
               (isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.85)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOfficialFeed
              ? (isMatchingDomain ? universityColor : universityColor.withOpacity(0.4))
              : theme.colorScheme.onSurface.withOpacity(0.08),
          width: isOfficialFeed && isMatchingDomain ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (appState.isGuest) {
                  final l10n = AppLocalizations.of(context)!;
                  askGuestToSignIn(context, appState, l10n.guestOpenTitle, l10n.guestOpenBody);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Poster banner & floating date badge
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'event-image-${event.id}',
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                            child: EventImage(url: event.imageUrl, color: universityColor),
                          ),
                        ),
                        // Shadow overlay for banner details
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // Floating Date Badge (Top-Left)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      dateBadgeMonth,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: universityColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      dateBadgeDay,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: theme.colorScheme.onSurface,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Card Details & CTAs (snug layout, zero empty space)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge & Categories Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOfficialFeed
                                    ? universityColor.withOpacity(0.12)
                                    : theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isOfficialFeed
                                    ? event.universityDomain.toUpperCase()
                                    : AppLocalizations.of(context)!.badgePublic,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isOfficialFeed ? universityColor : theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                            // List of categories (max 2 visual tags on tile)
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: event.categories.take(2).map((cat) => Container(
                                      margin: const EdgeInsets.only(left: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainer,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        categoryLabel(AppLocalizations.of(context)!, cat),
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Title & CTA button in the same line (very compact)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    event.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  // Who organizes it
                                  if (appState.hostOf(event.organizerId) case final host?)
                                    Text(
                                      AppLocalizations.of(context)!.byOrganizer(host.label),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildCtaButton(context, event, universityColor, theme, appState),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCtaButton(
    BuildContext context,
    Event event,
    Color brandColor,
    ThemeData theme,
    AppState appState,
  ) {
    final isRegistered = appState.isRegistered(event.id);
    final l10n = AppLocalizations.of(context)!;
    final ctaText = isRegistered
        ? (appState.isWaitlisted(event.id) ? l10n.ctaWaitlisted : l10n.ctaRegistered)
        : (event.requiresQrCode ? l10n.ctaRegister : l10n.ctaRsvp);

    return ElevatedButton(
      onPressed: isRegistered
          ? null
          : () => registerWithFeedback(context, appState, event),
      style: ElevatedButton.styleFrom(
        backgroundColor: isRegistered
            ? theme.colorScheme.surfaceContainer
            : brandColor,
        foregroundColor: isRegistered ? theme.colorScheme.onSurfaceVariant : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        ctaText,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _getMonthAbbreviation(DateTime date) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[date.month - 1];
  }
}
