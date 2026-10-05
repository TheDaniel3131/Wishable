// Feature: wishable, Property 16: JSON export/import round-trip equivalence
//
// Property-based test for task 6.3.
//
// **Property 16: JSON export/import round-trip equivalence**
// **Validates: Requirements 11.2, 12.1, 12.4**
//
// For any list of Wishes, exporting to a JSON_Export and then importing that
// JSON_Export produces a set of Wishes equivalent to the original set — equal
// on all domain fields, independent of ordering (design "Property 16").
//
// The codec operates on [SerializableWish] (the category embedded by name),
// which has value equality, so round-trip equivalence can be asserted directly
// on the decoded list.
//
// This is a pure-domain unit (no Flutter/Drift/dart:io), so it runs as a plain
// Dart test driven by `glados`.
library wishable.test.domain.wish_json_codec_test;

import 'package:glados/glados.dart';
import 'package:wishable/domain/lifecycle_status.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish_json_codec.dart';

void main() {
  const codec = WishJsonCodec();

  Glados<List<SerializableWish>>(_anyWishList).test(
    'decode(encode(wishes)) equals the original list as a multiset, '
    'independent of ordering',
    (wishes) {
      final encoded = codec.encode(wishes);
      final decoded = codec.decode(encoded);

      // Order-independent equivalence: the decoded wishes form the same
      // multiset as the originals (SerializableWish has value equality).
      expect(_multiset(decoded), equals(_multiset(wishes)));

      // Length is preserved (guards against duplicates being dropped).
      expect(decoded, hasLength(wishes.length));
    },
  );
}

/// Builds a multiset (element -> occurrence count) so equivalence can be
/// asserted independent of ordering while still being sensitive to duplicates.
Map<SerializableWish, int> _multiset(List<SerializableWish> wishes) {
  final counts = <SerializableWish, int>{};
  for (final w in wishes) {
    counts[w] = (counts[w] ?? 0) + 1;
  }
  return counts;
}

// --- Generators -------------------------------------------------------------

/// A generator for random lists of [SerializableWish].
final Generator<List<SerializableWish>> _anyWishList = any.list(_anyWish);

/// A generator for a single [SerializableWish] exercising the full input space
/// the codec must round-trip:
///   - titles including Unicode and special characters (and non-empty),
///   - descriptions including `null` and the empty string,
///   - arbitrary category names,
///   - every [Priority] and [LifecycleStatus] token,
///   - progress in the inclusive range [0, 100],
///   - UTC timestamps at the ISO-8601 millisecond precision the codec uses.
final Generator<SerializableWish> _anyWish = any.combine9(
  any.nonEmptyLetterOrDigits, // id (opaque string; letters/digits suffice)
  _anyText, // title (incl. Unicode/special chars)
  _anyOptionalText, // description (incl. null and '')
  _anyCategoryName, // category name
  any.choose(Priority.values), // priority
  any.choose(LifecycleStatus.values), // status
  any.intInRange(0, 101), // progress in [0, 100]
  _anyUtcTimestamp, // createdAtUtc
  _anyUtcTimestamp, // updatedAtUtc
  (
    String id,
    String title,
    String? description,
    String categoryName,
    Priority priority,
    LifecycleStatus status,
    int progress,
    DateTime createdAtUtc,
    DateTime updatedAtUtc,
  ) =>
      SerializableWish(
    id: id,
    title: title,
    description: description,
    categoryName: categoryName,
    priority: priority,
    status: status,
    progress: progress,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: updatedAtUtc,
  ),
);

/// Characters mixed into generated text to stress JSON escaping: ASCII letters
/// and digits plus JSON-significant and Unicode/special characters (quotes,
/// backslashes, newlines, tabs, braces, emoji, accented and CJK code points).
const String _specialChars =
    'abcABC123 "\\/\n\r\t{}[],:😀é中🚀\u0000\u001f';

/// A possibly-empty string drawn from [_specialChars]. Used for descriptions
/// where the empty string is a valid value.
final Generator<String> _anyText = any.stringOf(_specialChars);

/// A non-empty string drawn from [_specialChars]. Used for titles, which must
/// be non-empty (R1.2) — though the codec itself does not enforce that, a
/// realistic generator keeps titles non-empty.
final Generator<String> _anyNonEmptyText = any.nonEmptyStringOf(_specialChars);

/// A category name: an arbitrary non-empty string including special/Unicode
/// characters.
final Generator<String> _anyCategoryName = _anyNonEmptyText;

/// An optional description: `null`, the empty string, or arbitrary text
/// including Unicode/special characters.
final Generator<String?> _anyOptionalText = any.oneOf<String?>([
  any.null_,
  any.always<String?>(''),
  _anyText.map<String?>((s) => s),
]);

/// A UTC [DateTime] at millisecond precision — the precision the JSON codec's
/// ISO-8601 encoding preserves exactly. Generating at millisecond granularity
/// guarantees `decode(encode(t)) == t` for the timestamp fields (R12.4).
///
/// The epoch millisecond value is bounded to a wide-but-sane calendar range so
/// generated instants stay valid (roughly years 1973–2065).
final Generator<DateTime> _anyUtcTimestamp = any
    .intInRange(100000000000, 3000000000000)
    .map((ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
