/// Pure priority-sort helper (design "Data-Access Layer", R4.2).
///
/// Sorts a list of [Wish]es by [Priority] in non-increasing order — `High`
/// first, then `Medium`, then `Low`. The sort is **stable**: wishes that share
/// a priority keep their original relative order.
///
/// Dart's [List.sort] is not guaranteed to be stable, so this helper uses a
/// decorate-sort-undecorate strategy, tie-breaking on the original index to
/// preserve input order among equal-priority wishes. The input list is never
/// mutated — a new list is always returned.
///
/// Pure Dart over domain types: no Flutter, Drift, or dart:io dependencies.
library wishable.data.repositories.priority_sort;

import '../../domain/priority.dart';
import '../../domain/wish.dart';

/// Returns a new list containing [wishes] ordered by [Priority] from `High`
/// down to `Low` (R4.2), preserving the relative order of wishes that share a
/// priority (a stable sort). The [wishes] argument is not modified.
List<Wish> sortByPriorityHighToLow(List<Wish> wishes) {
  // Decorate: pair each wish with its original index so ties can be broken
  // deterministically, which is what makes the overall sort stable.
  final decorated = <_IndexedWish>[
    for (var i = 0; i < wishes.length; i++) _IndexedWish(i, wishes[i]),
  ];

  decorated.sort((a, b) {
    // Priority.high has the largest enum index, so comparing b to a yields a
    // non-increasing (High -> Low) ordering.
    final byPriority = b.wish.priority.index.compareTo(a.wish.priority.index);
    if (byPriority != 0) return byPriority;
    // Equal priority: fall back to original order to keep the sort stable.
    return a.index.compareTo(b.index);
  });

  // Undecorate: project back to plain wishes in their new order.
  return <Wish>[for (final entry in decorated) entry.wish];
}

/// A [Wish] paired with its original position in the input list, used to make
/// [sortByPriorityHighToLow] stable.
final class _IndexedWish {
  const _IndexedWish(this.index, this.wish);

  final int index;
  final Wish wish;
}
