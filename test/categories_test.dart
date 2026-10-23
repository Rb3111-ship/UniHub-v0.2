import 'package:flutter_test/flutter_test.dart';
import 'package:uni_events_app/core/models/categories.dart';

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
  });
}
