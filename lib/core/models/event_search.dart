import 'package:uni_events_app/l10n/app_localizations.dart';
import 'categories.dart';
import 'event_host.dart';
import 'event_model.dart';

/// Whether [event] matches the search box text. Every word must appear in the
/// title, a category (also its translated name), the organizer or the place.
bool matchesSearch(Event event, String query, EventHost? host, AppLocalizations l10n) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final haystack = [
    event.title,
    event.location,
    for (final c in event.categories) ...[c, categoryLabel(l10n, c)],
    host?.searchText ?? '',
  ].join(' ').toLowerCase();
  return words.every(haystack.contains);
}
