import 'package:flutter_test/flutter_test.dart';
import 'package:uni_events_app/core/models/categories.dart';
import 'package:uni_events_app/core/models/event_host.dart';

void main() {
  test('typed categories are cleaned up and checked', () {
    expect(normalizeCustomCategory('  Yoga   Club '), 'Yoga Club');
    expect(normalizeCustomCategory('music'), 'Music'); // maps to the built-in one
    expect(normalizeCustomCategory('Café & Kultur'), 'Café & Kultur');
    expect(normalizeCustomCategory('x'), isNull);
    expect(normalizeCustomCategory('a' * 31), isNull);
    expect(normalizeCustomCategory('<script>'), isNull);
    expect(normalizeCustomCategory('-dash first'), isNull);
  });

  test('the Other filter also finds custom categories', () {
    expect(matchesCategory(['Yoga'], 'Other'), isTrue);
    expect(matchesCategory(['Yoga'], 'Yoga'), isTrue);
    expect(matchesCategory(['Music'], 'Other'), isFalse);
    expect(matchesCategory(['Music'], 'All'), isTrue);
    expect(matchesCategory(['Tech', 'Other'], 'Other'), isTrue);
    expect(matchesCategory(['yoga'], 'Yoga'), isTrue); // case does not matter
  });

  test('Other lists at most 15 custom categories, most used first', () {
    final events = [
      for (var i = 0; i < 20; i++) ['Cat ${i.toString().padLeft(2, '0')}'],
      ['Yoga'], ['yoga', 'Music'], ['Yoga'],
    ];
    final top = topCustomCategories(events);
    expect(top.length, 15);
    expect(top.first.name, 'Yoga');
    expect(top.first.count, 3);
    expect(top.any((c) => c.name == 'Music'), isFalse); // built-in ones have their own chip
  });

  test('contact fields are checked and cleaned up', () {
    expect(EventContact.website(''), isNull);
    expect(EventContact.website('www.example.org'), 'https://www.example.org');
    expect(EventContact.website('http://example.org/a'), 'https://example.org/a');
    expect(EventContact.website('javascript:alert(1)'), '');
    expect(EventContact.website('not a link'), '');
    expect(EventContact.email('club@example.org'), 'club@example.org');
    expect(EventContact.email('club.example.org'), '');
    expect(EventContact.phone('+49 40 123-456'), '+49 40 123-456');
    expect(EventContact.phone('call me'), '');
  });
}
