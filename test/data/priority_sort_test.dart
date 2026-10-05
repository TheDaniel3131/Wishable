// Feature: wishable, Property 7: Priority sort is an ordered permutation
//
// Property-based tests for [sortByPriorityHighToLow] (lib/data/repositories/
// priority_sort.dart).
//
// **Validates: Requirements 4.2**
//
// Property 7 asserts that the priority sort is an *ordered permutation* of its
// input. Concretely, for any list of wishes:
//   1. the result is a PERMUTATION of the input (same multiset of wishes — no
//      additions, drops, or duplications);
//   2. the result is ordered non-increasing by priority (High before Medium
//      before Low);
//   3. the sort is STABLE — wishes of equal priority keep their original
//      relative order; and
//   4. the input list is not mutated.
//
// Pure logic: wishes are constructed directly, no database involved.

import 'package:glados/glados.dart';
import 'package:wishable/data/repositories/priority_sort.dart';
import 'package:wishable/domain/lifecycle_status.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';

/// A generator for arbitrary [Wish]es whose [Priority] varies across all three
/// values, with the remaining fields drawn arbitrarily. Priority is the field
/// under test, so the generator ensures all of Low/Medium/High appear.
Generator<Wish> wishGenerator() {
  return any.combine8(
    any.int, // index into the UUID space — kept simple but varied via id below
    any.letterOrDigits, // title
    any.choose(<String?>[null, '', 'desc', 'a longer description']), // desc
    any.letterOrDigits, // categoryId
    // Priority varies across all three values — it is the field under test.
    any.choose(const <Priority>[Priority.low, Priority.medium, Priority.high]),
    any.choose(const <LifecycleStatus>[
      LifecycleStatus.active,
      LifecycleStatus.inProgress,
      LifecycleStatus.completed,
    ]),
    any.intInRange(0, 101), // progress in [0, 100]
    any.intInRange(0, 1 << 30), // epoch seconds seed for timestamps
    (idSeed, title, description, categoryId, priority, status, progress,
        tsSeed) {
      final created =
          DateTime.fromMillisecondsSinceEpoch(tsSeed * 1000, isUtc: true);
      return Wish(
        id: 'wish-$idSeed',
        title: title,
        description: description,
        categoryId: 'cat-$categoryId',
        priority: priority,
        status: status,
        progress: progress,
        createdAtUtc: created,
        updatedAtUtc: created,
      );
    },
  );
}

/// Returns a multiset (value -> count) of the given wishes so two lists can be
/// compared for being permutations regardless of order.
Map<Wish, int> _multiset(List<Wish> wishes) {
  final counts = <Wish, int>{};
  for (final wish in wishes) {
    counts[wish] = (counts[wish] ?? 0) + 1;
  }
  return counts;
}

void main() {
  // Minimum 100 generated cases (glados default is 100).
  Glados(any.listWithLengthInRange(0, 30, wishGenerator()))
      .test('priority sort is an ordered permutation (Property 7)',
          (List<Wish> input) {
    // Keep an independent snapshot to detect mutation of the input argument.
    final snapshot = List<Wish>.of(input);

    final sorted = sortByPriorityHighToLow(input);

    // (1) PERMUTATION: same multiset of wishes — nothing added, dropped, or
    // duplicated.
    expect(sorted.length, input.length);
    expect(_multiset(sorted), _multiset(input));

    // (2) ORDERED non-increasing by priority (High before Medium before Low).
    for (var i = 1; i < sorted.length; i++) {
      expect(
        sorted[i - 1].priority.index >= sorted[i].priority.index,
        isTrue,
        reason: 'result must be non-increasing by priority at index $i: '
            '${sorted[i - 1].priority} then ${sorted[i].priority}',
      );
    }

    // (3) STABILITY: within each priority band, the relative order of wishes
    // matches their order in the input. We verify this per priority value by
    // projecting both lists down to a single priority and comparing by
    // identity (object order), which captures original relative order.
    for (final priority in Priority.values) {
      final fromInput = [
        for (final w in input)
          if (w.priority == priority) w,
      ];
      final fromSorted = [
        for (final w in sorted)
          if (w.priority == priority) w,
      ];
      expect(fromSorted.length, fromInput.length);
      for (var i = 0; i < fromInput.length; i++) {
        expect(
          identical(fromSorted[i], fromInput[i]),
          isTrue,
          reason: 'stability violated for $priority at position $i',
        );
      }
    }

    // (4) INPUT NOT MUTATED: the argument list is unchanged in both length and
    // element order.
    expect(input.length, snapshot.length);
    for (var i = 0; i < snapshot.length; i++) {
      expect(identical(input[i], snapshot[i]), isTrue,
          reason: 'input list was mutated at index $i');
    }
  });
}
