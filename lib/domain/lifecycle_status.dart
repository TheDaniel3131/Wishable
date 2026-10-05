/// The lifecycle status of a [Wish].
///
/// A Wish starts [active] on creation (design R1.1/R6.1), moves to
/// [inProgress] when work begins or progress rises above 0 (R6.2, R5.3), and
/// reaches [completed] when progress hits 100 or the user marks it complete
/// (R5.4, R6.3). A completed Wish may be reopened back to [inProgress] (R6.4).
///
/// The integer index of each value is persisted by Drift via
/// `intEnum<LifecycleStatus>()`, so the declaration order is part of the
/// on-disk schema and MUST NOT be reordered.
library wishable.domain.lifecycle_status;

enum LifecycleStatus {
  active,
  inProgress,
  completed,
}
