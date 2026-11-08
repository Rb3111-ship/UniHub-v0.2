import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/models/categories.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/event_search.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import 'event_cards.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  bool _savedOnly = false;

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
        .where((e) => !_savedOnly || appState.isFavorite(e.id))
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
                    color: theme.brightness == Brightness.dark ? theme.colorScheme.secondary : appState.getActiveTenantColor(),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              Text(
                guest ? localizations.guestFeedTitle : localizations.homeGreeting(_firstName(appState)),
                style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24),
              ),
            ],
          );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: titleWidget,
          actions: [
            if (!guest && !_searching)
              IconButton(
                tooltip: _savedOnly ? localizations.savedShowAll : localizations.savedShowOnly,
                isSelected: _savedOnly,
                icon: Icon(_savedOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _savedOnly ? Colors.redAccent : null),
                onPressed: () => setState(() => _savedOnly = !_savedOnly),
              ),
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
                    key: const Key('categoryChips'),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final key = cat['key'] as String;
                      final isSelected = key == 'Other' ? (selected == 'Other' || customSelected) : selected == key;
                      final scheme = theme.colorScheme;

                      return ChoiceChip(
                        showCheckmark: false,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat['icon'] as IconData,
                              size: 16,
                              color: isSelected ? scheme.onPrimary : scheme.secondary,
                            ),
                            const SizedBox(width: 6),
                            Text(cat['label'] as String),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: scheme.primary,
                        backgroundColor: theme.cardTheme.color,
                        labelStyle: TextStyle(
                          color: isSelected ? scheme.onPrimary : scheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
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
      return const FeedSkeleton();
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
            const SizedBox(height: 40),
            EmptyState(
              icon: _searchController.text.trim().isNotEmpty
                  ? Icons.search_off_rounded
                  : _savedOnly
                      ? Icons.favorite_border_rounded
                      : Icons.event_note_rounded,
              title: _searchController.text.trim().isNotEmpty
                  ? l10n.searchNoResults
                  : _savedOnly
                      ? l10n.savedEmpty
                      : l10n.eventsEmptyCategory,
            ),
          ],
        ),
      );
    }

    // The soonest event with a poster leads (or simply the soonest one).
    final featured = events.take(5).firstWhere((e) => e.imageUrl != null, orElse: () => events.first);
    final rest = [for (final e in events) if (e.id != featured.id) e];
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: appState.refreshEvents,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(child: PressScale(child: FeaturedEventCard(event: featured))),
                  if (rest.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(l10n.homeComingUp, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 10),
                    for (final (i, e) in rest.indexed) ...[
                      FadeSlideIn(index: i + 1, child: PressScale(child: EventRowCard(event: e))),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _firstName(AppState appState) {
    final name = appState.activeProfile.name.trim();
    return name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
  }
}
