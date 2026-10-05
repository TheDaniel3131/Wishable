// Feature: wishable, Property 11: Completion emits a celebration event carrying the title
//
// Property-based test for task 11.7.
//
// **Property 11: Completion emits a celebration event carrying the title**
// **Validates: Requirements 7.1, 7.3**
//
// For any Wish, when a lifecycle transition RESULTS in `Completed` and the Wish
// was NOT already `Completed`, the [CelebrationController] emits EXACTLY ONE
// [CelebrationEvent] carrying the completed Wish's title (R7.1, R7.3). When a
// transition does NOT result in a fresh completion — the result is not
// `Completed`, or the Wish was already `Completed` so there is no new edge —
// NO event is emitted.
//
// The test exercises the pure application-layer [CelebrationController]
// directly: it constructs the controller, subscribes to [events], and calls
// [CelebrationController.notifyTransition] with randomly generated before/after
// Wishes that differ only in lifecycle [status]. Because the controller is pure
// logic over the Domain ([Wish], [LifecycleStatus]) with no Flutter, Drift, or
// I/O, no mocks or database are needed and the assertions are deterministic.
//
// Generators produce a random before/after status pair (covering all 3x3
// combinations, including the already-Completed and self-transition cases) and
// a random non-empty title. The oracle for a fresh completion is
// `after == completed && before != completed`. For each generated case the test
// asserts:
//
//   - an event is emitted iff the transition is a fresh completion;
//   - when emitted, exactly ONE event fires (not zero, not many);
//   - the emitted event's `title` equals the completed Wish's `title` (R7.3)
//     and its `wishId` equals the Wish's id;
//   - when it is not a fresh completion, the stream stays silent and
//     `lastEvent` is unchanged.
//
// Minimum 100 generated cases. The language and framework (Dart property
// testing via `glados`) follow the design's Testing Strategy. glados'
// `expect`/`test` clash with flutter_test's, so those two are hidden and
// flutter_test provides the runner and matchers (and the async-aware
// `expectLater` used to collect stream emissions).
library wishable.test.application.celebration_controller_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, test;
import 'package:wishable/application/controllers/celebration_controller.dart';
import 'package:wishable/domain/lifecycle_status.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';

void main() {
  // 100 generated cases: a random (before, after) status pair plus a random
  // non-empty title, each run against a fresh controller so the cases stay
  // fully isolated.
  Glados<_TransitionCase>(_anyTransitionCase, ExploreConfig(numRuns: 100)).test(
    'notifyTransition emits exactly one event carrying the title iff the '
    'transition is a fresh completion, and nothing otherwise',
    (_TransitionCase testCase) async {
      final CelebrationController controller = CelebrationController();

      // Collect every event emitted on the broadcast stream. We don't close
      // the controller until after draining a microtask turn so that any
      // synchronous emission has been delivered to this listener.
      final List<CelebrationEvent> emitted = <CelebrationEvent>[];
      final subscription = controller.events.listen(emitted.add);

      try {
        // before/after are the same Wish differing only in lifecycle status,
        // so the only thing that can trigger (or not) a celebration is the
        // status edge — the title is held constant and used as the oracle.
        final Wish before = _wish(
          id: testCase.id,
          title: testCase.title,
          status: testCase.before,
        );
        final Wish after = before.copyWith(status: testCase.after);

        final CelebrationEvent? returned =
            controller.notifyTransition(before, after);

        // Let the broadcast stream deliver any queued event to the listener.
        await Future<void>.delayed(Duration.zero);

        final bool freshCompletion =
            testCase.after == LifecycleStatus.completed &&
                testCase.before != LifecycleStatus.completed;

        if (freshCompletion) {
          // Exactly one event — not zero, not many (R7.1).
          expect(emitted, hasLength(1),
              reason: 'a fresh completion must emit exactly one event (R7.1): '
                  '$testCase');
          final CelebrationEvent event = emitted.single;

          // The event carries the completed Wish's title (R7.3) and id.
          expect(event.title, equals(testCase.title),
              reason: 'the event must carry the completed Wish title (R7.3)');
          expect(event.wishId, equals(testCase.id),
              reason: 'the event must identify the completed Wish');

          // The direct return value and the retained lastEvent agree with the
          // streamed event.
          expect(returned, isNotNull,
              reason: 'notifyTransition must return the emitted event');
          expect(returned, equals(event));
          expect(controller.lastEvent, equals(event),
              reason: 'lastEvent must retain the emitted event');
        } else {
          // No fresh completion => total silence (R7.1): no stream event, no
          // return value, no retained event.
          expect(emitted, isEmpty,
              reason: 'no event may be emitted when the transition is not a '
                  'fresh completion: $testCase');
          expect(returned, isNull,
              reason: 'notifyTransition must return null when nothing fires');
          expect(controller.lastEvent, isNull,
              reason: 'lastEvent must stay null when nothing fires');
        }
      } finally {
        await subscription.cancel();
        controller.dispose();
      }
    },
  );
}

/// Builds a [Wish] with the generated [id], [title] and [status]. The remaining
/// fields are fixed constants: Property 11 depends only on the status edge and
/// the title, so holding everything else steady keeps the before/after pair
/// differing by status alone.
Wish _wish({
  required String id,
  required String title,
  required LifecycleStatus status,
}) {
  final DateTime created = DateTime.utc(2024, 1, 1);
  return Wish(
    id: id,
    title: title,
    description: null,
    categoryId: 'category-fixed',
    priority: Priority.medium,
    status: status,
    // Completed Wishes carry progress 100 by the lifecycle invariant; other
    // statuses carry 0. The value is irrelevant to Property 11 but kept legal.
    progress: status == LifecycleStatus.completed ? 100 : 0,
    createdAtUtc: created,
    updatedAtUtc: created,
  );
}

// --- Case specification + generators ----------------------------------------

/// One transition case: the before/after lifecycle statuses plus the Wish's id
/// and title (the title is the value asserted on emission, R7.3).
class _TransitionCase {
  const _TransitionCase({
    required this.before,
    required this.after,
    required this.id,
    required this.title,
  });

  final LifecycleStatus before;
  final LifecycleStatus after;
  final String id;
  final String title;

  @override
  String toString() => '_TransitionCase(before: ${before.name}, '
      'after: ${after.name}, id: $id, title: $title)';
}

/// Characters mixed into generated titles to stress rendering/escaping.
const String _specialChars = 'abcABC123 "\\/\n\r\t{}[],:😀é中🚀';

/// Any [LifecycleStatus] — covers active / inProgress / completed so the
/// before/after pair spans all 3x3 combinations, including already-Completed
/// and self-transitions.
final Generator<LifecycleStatus> _anyStatus =
    any.choose(LifecycleStatus.values);

/// A non-empty title (R1.2), including unicode and whitespace-heavy inputs.
final Generator<String> _anyTitle = any.nonEmptyStringOf(_specialChars);

/// A non-empty id for the Wish.
final Generator<String> _anyId = any.nonEmptyStringOf(_specialChars);

final Generator<_TransitionCase> _anyTransitionCase = any.combine4(
  _anyStatus,
  _anyStatus,
  _anyId,
  _anyTitle,
  (LifecycleStatus before, LifecycleStatus after, String id, String title) =>
      _TransitionCase(before: before, after: after, id: id, title: title),
);
