/// Lifecycle events that drive a [Wish] through its state machine.
///
/// These are the inputs to the pure `LifecyclePolicy` function
/// `(status, progress, event) -> (status, progress)` (added in task 4). Each
/// event corresponds to a user action in the design "Wish lifecycle state
/// machine" section:
///
///   - [StartEvent]      Active -> In_Progress (R6.2)
///   - [CompleteEvent]   any -> Completed, progress := 100 (R6.3)
///   - [ReopenEvent]     Completed -> In_Progress, progress retained (R6.4)
///   - [ProgressChanged] set progress; 0 -> >0 implies In_Progress,
///                       100 implies Completed (R5.3, R5.4)
///
/// This is a pure sealed hierarchy: it carries no I/O and no Flutter/Drift
/// dependencies, so the policy that consumes it can be exhaustively matched
/// and property-tested.
library wishable.domain.lifecycle_event;

/// Base type for all lifecycle events.
///
/// Sealed so that `switch` statements over events are exhaustively checked by
/// the analyzer, guaranteeing the state machine handles every event kind.
sealed class LifecycleEvent {
  const LifecycleEvent();
}

/// The user marks an `Active` Wish as started (R6.2).
///
/// Value objects of this type are interchangeable, so all instances compare
/// equal.
final class StartEvent extends LifecycleEvent {
  const StartEvent();

  @override
  bool operator ==(Object other) => other is StartEvent;

  @override
  int get hashCode => (StartEvent).hashCode;

  @override
  String toString() => 'StartEvent()';
}

/// The user marks a Wish as complete: status becomes `Completed` and progress
/// is forced to 100 (R6.3).
final class CompleteEvent extends LifecycleEvent {
  const CompleteEvent();

  @override
  bool operator ==(Object other) => other is CompleteEvent;

  @override
  int get hashCode => (CompleteEvent).hashCode;

  @override
  String toString() => 'CompleteEvent()';
}

/// The user reopens a `Completed` Wish: status becomes `In_Progress` and the
/// stored progress is retained (R6.4).
final class ReopenEvent extends LifecycleEvent {
  const ReopenEvent();

  @override
  bool operator ==(Object other) => other is ReopenEvent;

  @override
  int get hashCode => (ReopenEvent).hashCode;

  @override
  String toString() => 'ReopenEvent()';
}

/// The user changes a Wish's progress to [value].
///
/// The policy interprets the value: a change from 0 to a value greater than 0
/// moves the Wish to `In_Progress` (R5.3), a value of 100 moves it to
/// `Completed` (R5.4), and a value outside the range [0, 100] is rejected by
/// the policy, leaving the stored progress unchanged (R5.2).
final class ProgressChanged extends LifecycleEvent {
  const ProgressChanged(this.value);

  /// The requested progress value. Not validated here; the policy enforces the
  /// [0, 100] bound.
  final int value;

  @override
  bool operator ==(Object other) =>
      other is ProgressChanged && other.value == value;

  @override
  int get hashCode => Object.hash(ProgressChanged, value);

  @override
  String toString() => 'ProgressChanged($value)';
}
