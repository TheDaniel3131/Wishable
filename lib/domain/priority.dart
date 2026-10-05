/// The priority of a [Wish].
///
/// New Wishes default to [medium] (design R1.4). The integer index of each
/// value is persisted by Drift via `intEnum<Priority>()`, so the declaration
/// order is part of the on-disk schema and MUST NOT be reordered. The order
/// Low → Medium → High is also used by the priority sort (R4.2).
library wishable.domain.priority;

enum Priority {
  low,
  medium,
  high,
}
