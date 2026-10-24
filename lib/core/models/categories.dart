import 'package:flutter/material.dart';
import 'package:uni_events_app/l10n/app_localizations.dart';

/// The built-in categories. Anything else on an event is a custom category an
/// organizer typed in (via "Other").
const standardCategories = ['Music', 'Tech', 'Sports', 'Arts', 'Academic', 'Other'];

const maxCustomCategoryLength = 30;

bool isStandardCategory(String category) => standardCategories.contains(category);

/// Letters (any language), digits, spaces and a few separators.
final _customCategoryPattern = RegExp(r"^[\p{L}\p{N}][\p{L}\p{N} &'+\-]*$", unicode: true);

/// Cleans up a typed category: trims, collapses spaces, and maps "music" etc. to
/// the built-in key. Returns null if it is not usable.
String? normalizeCustomCategory(String input) {
  final text = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length < 2 || text.length > maxCustomCategoryLength) return null;
  if (!_customCategoryPattern.hasMatch(text)) return null;
  for (final key in standardCategories) {
    if (key.toLowerCase() == text.toLowerCase()) return key;
  }
  return text;
}

String categoryLabel(AppLocalizations l10n, String key) => switch (key) {
      'Music' => l10n.categoryMusic,
      'Tech' => l10n.categoryTech,
      'Sports' => l10n.categorySports,
      'Arts' => l10n.categoryArts,
      'Academic' => l10n.categoryAcademic,
      'Other' => l10n.categoryOther,
      _ => key,
    };

IconData categoryIcon(String key) => switch (key) {
      'Music' => Icons.music_note_rounded,
      'Tech' => Icons.code_rounded,
      'Sports' => Icons.sports_soccer_rounded,
      'Arts' => Icons.palette_rounded,
      'Academic' => Icons.menu_book_rounded,
      'Other' => Icons.more_horiz_rounded,
      _ => Icons.label_rounded,
    };

/// Whether an event with [categories] shows up under the filter [selected].
/// "Other" also covers every custom category.
bool matchesCategory(List<String> categories, String selected) {
  if (selected == 'All') return true;
  if (selected == 'Other') return categories.any((c) => c == 'Other' || !isStandardCategory(c));
  final wanted = selected.toLowerCase();
  return categories.any((c) => c.toLowerCase() == wanted);
}

/// At most this many custom categories are offered under "Other".
const maxOtherCategories = 15;

/// The custom categories used by the most events (ties: alphabetical), at most
/// [maxOtherCategories]. Recomputed whenever the feed reloads.
List<({String name, int count})> topCustomCategories(Iterable<List<String>> eventCategories) {
  final counts = <String, int>{};
  final names = <String, String>{};
  for (final cats in eventCategories) {
    for (final c in cats.toSet()) {
      if (isStandardCategory(c)) continue;
      final key = c.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      names.putIfAbsent(key, () => c);
    }
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return [for (final k in keys.take(maxOtherCategories)) (name: names[k]!, count: counts[k]!)];
}
