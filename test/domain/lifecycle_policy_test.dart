// Feature: wishable, Property 9: Lifecycle state machine preserves its invariants
//
// Property-based test for task 4.2.
//
// Property 9: Lifecycle state machine preserves its invariants.
// Validates: Requirements 1.1, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4.
//
// This test exercises the pure state machine [LifecyclePolicy.apply] over
// randomly generated starting states and random sequences of
// [LifecycleEvent]s (Start / ProgressChanged / Complete / Reopen). After every
// single [apply] it asserts the invariants documented on the policy together
// with the specific transition rules from the design:
//
//   - A newly created Wish is Active with progress 0 (R1.1, R6.1).
//   - Raising progress from 0 to a value > 0 yields In_Progress (R5.3, R6.2).
//   - Setting progress to 100, or applying Complete, yields Completed with
//     progress 100 (R5.4, R6.3).
//   - Reopening a Completed Wish yields In_Progress retaining stored progress
//     (R6.4).
//   - progress is always in [0, 100] (R5.1/R5.2 bound).
//   - status == Completed implies progress == 100 (R5.4, R6.3).
//
// The language and framework (Dart property testing via `glados`) follow the
// design's Testing Strategy. The policy under test is pure, so the test needs
// no mocks and runs entirely in memory.

import 'package:glados/glados.dart';
import 'package:wishable/domain/lifecycle_event.dart';
import 'package:wishable/domain/lifecycle_policy.dart';
import 'package:wishable/domain/lifecycle_status.dart';

/// Generators for the lifecycle domain, registered on glados' [Any] namespace.
extension LifecycleAnys on Any {
  /// Any [LifecycleStatus].
  Generator<LifecycleStatus> get lifecycleStatus =>
      choose(LifecycleStatus.values);

  /// A valid progress value in the inclusive range [0, 100].
  Generator<int> get progress => intInRange(0, 101);

  /// A single [LifecycleEvent]. [ProgressChanged] values deliberately include
  /// out-of-range values (negative and > 100) so the test exercises the
  /// policy's rejection path, plus the boundary values 0 and 100 which drive
  /// status transitions.
  Generator<LifecycleEvent> get lifecycleEvent => oneOf<LifecycleEvent>([
        always(const StartEvent()),
        always(const CompleteEvent()),
        always(const ReopenEvent()),
        intInRange(-20, 121).map<LifecycleEvent>((int v) => ProgressChanged(v)),
      ]);

  /// A sequence of lifecycle events.
  Generator<List<LifecycleEvent>> get lifecycleEvents =>
      list(lifecycleEvent);
}

/// Asserts every invariant that must hold for a [LifecycleState] produced by
/// the policy, given the state it was derived from.
void _expectInvariants(
  LifecycleState result, {
  required LifecycleState previous,
  required LifecycleEvent event,
}) {
  // Invariant: progress is always within [0, 100].
  expect(
    result.progress,
    inInclusiveRange(LifecyclePolicy.minProgress, LifecyclePolicy.maxProgress),
    reason: 'progress out of range after $event from $previous -> $result',
  );

  // Invariant: Completed implies progress == 100.
  if (result.status == LifecycleStatus.completed) {
    expect(
      result.progress,
      LifecyclePolicy.maxProgress,
      reason: 'Completed must have progress 100 after $event from $previous',
    );
  }

  // Invariant: progress > 0 implies status != Active.
  if (result.progress > 0) {
    expect(
      result.status,
      isNot(LifecycleStatus.active),
      reason: 'progress > 0 must not be Active after $event from $previous',
    );
  }

  // Transition rule: Complete always yields Completed with progress 100.
  if (event is CompleteEvent) {
    expect(result.status, LifecycleStatus.completed);
    expect(result.progress, LifecyclePolicy.maxProgress);
  }

  // Transition rule: ProgressChanged(100) yields Completed with progress 100.
  if (event is ProgressChanged && event.value == LifecyclePolicy.maxProgress) {
    expect(result.status, LifecycleStatus.completed);
    expect(result.progress, LifecyclePolicy.maxProgress);
  }

  // Transition rule: raising progress from 0 to a value in (0, 100) yields
  // In_Progress carrying the new progress value.
  if (event is ProgressChanged &&
      previous.progress == 0 &&
      event.value > 0 &&
      event.value < LifecyclePolicy.maxProgress) {
    expect(
      result.status,
      LifecycleStatus.inProgress,
      reason: 'raising progress 0 -> ${event.value} must be In_Progress',
    );
    expect(result.progress, event.value);
  }

  // Transition rule: reopening a Completed Wish yields In_Progress retaining
  // the stored progress (which is 100 while Completed).
  if (event is ReopenEvent && previous.status == LifecycleStatus.completed) {
    expect(result.status, LifecycleStatus.inProgress);
    expect(result.progress, previous.progress);
  }

  // Transition rule: an out-of-range ProgressChanged is rejected, leaving the
  // state unchanged.
  if (event is ProgressChanged &&
      (event.value < LifecyclePolicy.minProgress ||
          event.value > LifecyclePolicy.maxProgress)) {
    expect(result.status, previous.status);
    expect(result.progress, previous.progress);
  }
}

void main() {
  // A newly created Wish is Active with progress 0 (R1.1, R6.1). This is the
  // canonical start state the state machine builds on.
  const LifecycleState created =
      LifecycleState(LifecycleStatus.active, 0);

  Glados<List<LifecycleEvent>>(any.lifecycleEvents).test(
    'created Wish starts Active/0 and invariants hold after every event',
    (List<LifecycleEvent> events) {
      // A created Wish is Active with progress 0.
      expect(created.status, LifecycleStatus.active);
      expect(created.progress, 0);

      LifecycleState state = created;
      for (final LifecycleEvent event in events) {
        final LifecycleState previous = state;
        final LifecycleState next =
            LifecyclePolicy.apply(previous.status, previous.progress, event);
        _expectInvariants(next, previous: previous, event: event);
        state = next;
      }
    },
  );

  // The same invariants must hold starting from any reachable (status,
  // progress) pair, not only from the created state. We constrain the random
  // start to pairs that already satisfy the policy's invariants so the fold
  // begins from a legal state.
  Glados3<LifecycleStatus, int, List<LifecycleEvent>>(
    any.lifecycleStatus,
    any.progress,
    any.lifecycleEvents,
  ).test(
    'invariants hold from any legal start state across an event sequence',
    (LifecycleStatus startStatus, int startProgress,
        List<LifecycleEvent> events) {
      // Normalize the random start into a legal state so the precondition
      // (Completed => progress 100, progress > 0 => not Active) holds before
      // the first apply; otherwise we would be testing the policy against an
      // impossible input.
      LifecycleStatus status = startStatus;
      int progress = startProgress;
      if (status == LifecycleStatus.completed) {
        progress = LifecyclePolicy.maxProgress;
      }
      if (progress > 0 && status == LifecycleStatus.active) {
        status = LifecycleStatus.inProgress;
      }

      LifecycleState state = LifecycleState(status, progress);
      for (final LifecycleEvent event in events) {
        final LifecycleState previous = state;
        final LifecycleState next =
            LifecyclePolicy.apply(previous.status, previous.progress, event);
        _expectInvariants(next, previous: previous, event: event);
        state = next;
      }
    },
  );
}
