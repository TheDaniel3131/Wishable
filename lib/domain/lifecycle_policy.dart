/// The [LifecyclePolicy] — the pure state machine that governs how a [Wish]
/// moves between lifecycle statuses as events are applied.
///
/// This is the single source of truth for all lifecycle rules (design "Wish
/// lifecycle state machine"; R5.3, R5.4, R6.1–R6.4). Every mutation path in
/// the app — explicit start/complete/reopen actions and progress changes —
/// routes through [LifecyclePolicy.apply] so they all obey the same
/// invariants.
///
/// The policy is a pure function
/// `(LifecycleStatus status, int progress, LifecycleEvent event)
///     -> (LifecycleStatus, int progress)`
/// expressed as [LifecyclePolicy.apply], returning the next [LifecycleState].
/// It performs no I/O and has no Flutter/Drift/dart:io dependencies, so it is
/// exhaustively matchable and property-testable.
///
/// Transition table (design):
///
/// | Current status       | Event                         | Next status | Progress effect |
/// | -------------------- | ----------------------------- | ----------- | --------------- |
/// | Active               | Start                         | In_Progress | unchanged       |
/// | Active / In_Progress | ProgressChanged(p), 0→p>0     | In_Progress | p               |
/// | any                  | ProgressChanged(100)          | Completed   | 100             |
/// | any                  | Complete                      | Completed   | set to 100      |
/// | Completed            | Reopen                        | In_Progress | retained        |
/// | any                  | ProgressChanged(p<0 or p>100) | unchanged   | rejected        |
///
/// Invariants that hold after every [apply] (design "Derived invariants"):
///
///   - `progress ∈ [0, 100]` always (R5.1, R5.2).
///   - `status == Completed ⇒ progress == 100` (R5.4, R6.3).
///   - `progress > 0 ⇒ status != Active` (R5.3).
library wishable.domain.lifecycle_policy;

import 'lifecycle_event.dart';
import 'lifecycle_status.dart';

/// The immutable `(status, progress)` pair produced by [LifecyclePolicy.apply].
///
/// Represents the lifecycle-relevant portion of a [Wish] state: its
/// [LifecycleStatus] and its integer [progress] in the inclusive range
/// `[0, 100]`. Compared by value.
final class LifecycleState {
  const LifecycleState(this.status, this.progress);

  /// The lifecycle status component of the state.
  final LifecycleStatus status;

  /// The progress component of the state, in the inclusive range `[0, 100]`.
  final int progress;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LifecycleState &&
          other.status == status &&
          other.progress == progress;

  @override
  int get hashCode => Object.hash(status, progress);

  @override
  String toString() => 'LifecycleState($status, $progress)';
}

/// Pure state machine for the [Wish] lifecycle.
///
/// All members are static; the class is not meant to be instantiated.
abstract final class LifecyclePolicy {
  /// Lowest valid [LifecycleState.progress] value (R5.1).
  static const int minProgress = 0;

  /// Highest valid [LifecycleState.progress] value; also the value that marks
  /// a Wish [LifecycleStatus.completed] (R5.1, R5.4).
  static const int maxProgress = 100;

  /// Computes the next [LifecycleState] from the current ([status], [progress])
  /// and the applied [event].
  ///
  /// The function is total and pure: it never throws and never performs I/O.
  /// An event that would carry the state out of bounds — a
  /// [ProgressChanged] whose value is below [minProgress] or above
  /// [maxProgress] — is rejected by returning the current state unchanged
  /// (R5.2). Every returned state satisfies the invariants documented on
  /// [LifecyclePolicy].
  static LifecycleState apply(
    LifecycleStatus status,
    int progress,
    LifecycleEvent event,
  ) {
    return switch (event) {
      // Active -> In_Progress; progress unchanged. From any other status the
      // start action has no defined effect, so the state is left unchanged.
      StartEvent() => status == LifecycleStatus.active
          ? LifecycleState(LifecycleStatus.inProgress, progress)
          : LifecycleState(status, progress),

      // Mark complete: Completed with progress forced to 100 (R6.3).
      CompleteEvent() =>
        const LifecycleState(LifecycleStatus.completed, maxProgress),

      // Reopen a Completed Wish -> In_Progress, retaining stored progress
      // (R6.4). Reopen on a non-Completed Wish is a no-op.
      ReopenEvent() => status == LifecycleStatus.completed
          ? LifecycleState(LifecycleStatus.inProgress, progress)
          : LifecycleState(status, progress),

      // Set progress; interpret the resulting status (R5.2, R5.3, R5.4).
      ProgressChanged(:final value) => _applyProgress(status, progress, value),
    };
  }

  /// Applies a [ProgressChanged] value, enforcing the progress bound and
  /// resolving the implied status.
  ///
  /// Rules:
  ///   - value outside [minProgress, maxProgress]: reject, state unchanged
  ///     (R5.2).
  ///   - value == 100: Completed with progress 100 (R5.4).
  ///   - value > 0 (and < 100): In_Progress with the new progress; a rise from
  ///     0 to >0 moves Active -> In_Progress (R5.3), and lowering a Completed
  ///     Wish below 100 leaves it In_Progress so the Completed⇒100 invariant
  ///     holds.
  ///   - value == 0: progress 0; a Completed Wish moves to In_Progress to
  ///     preserve the Completed⇒100 invariant, otherwise the status is
  ///     retained.
  static LifecycleState _applyProgress(
    LifecycleStatus status,
    int progress,
    int value,
  ) {
    if (value < minProgress || value > maxProgress) {
      return LifecycleState(status, progress);
    }
    if (value == maxProgress) {
      return const LifecycleState(LifecycleStatus.completed, maxProgress);
    }
    if (value > minProgress) {
      return LifecycleState(LifecycleStatus.inProgress, value);
    }
    // value == 0: keep status unless Completed (which would break the
    // Completed ⇒ progress == 100 invariant).
    final nextStatus = status == LifecycleStatus.completed
        ? LifecycleStatus.inProgress
        : status;
    return LifecycleState(nextStatus, minProgress);
  }
}
