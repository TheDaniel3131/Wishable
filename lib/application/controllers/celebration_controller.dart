/// The [CelebrationController] — the application-layer view-model that watches
/// Wish lifecycle transitions and raises a single celebration event each time
/// a Wish becomes [LifecycleStatus.completed] (task 11.5).
///
/// ## Responsibility (R7.1, R7.3)
///
/// When a Wish transitions to `Completed`, the UI shows the Celebration View
/// containing "Wish fulfilled" and the completed Wish's title (R7.1, R7.3).
/// This controller is the seam between the mutation path — [WishActionController]
/// / repository calls that return the resulting [Wish] — and that overlay. It
/// does NOT render anything; it only decides *when* a celebration is due and
/// *what* title to show, then publishes a [CelebrationEvent] the presentation
/// layer listens to.
///
/// ## "Exactly once per completion"
///
/// A celebration fires only on the *edge* into `Completed`: the resulting
/// status must be `Completed` AND the previous status must NOT already have
/// been `Completed`. Re-applying an event to an already-completed Wish (for
/// example a redundant progress update that leaves it at 100) therefore does
/// not re-fire. This matches design Property 11: a celebration event is
/// emitted exactly once for a transition whose resulting status is
/// `Completed`.
///
/// ## Layering discipline
///
/// Pure application layer: depends only on the Domain ([Wish],
/// [LifecycleStatus]) and Riverpod. No Flutter widgets, Drift, or dart:io.
/// Events are published on a broadcast [Stream] so any number of UI listeners
/// (and tests) can observe them without coupling to each other.
library wishable.application.controllers.celebration_controller;

import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../../domain/domain.dart';

/// An immutable celebration event: the payload the Celebration View renders.
///
/// Carries the completed Wish's [title] (R7.3, the value actually shown) and
/// its [wishId] so a listener can correlate the event with a specific Wish
/// (for example to route back to it on dismissal). Compared by value.
final class CelebrationEvent {
  const CelebrationEvent({required this.wishId, required this.title});

  /// Convenience constructor that extracts [wishId] and [title] from a
  /// completed [Wish].
  CelebrationEvent.forWish(Wish wish) : wishId = wish.id, title = wish.title;

  /// The stable id of the Wish that was completed.
  final String wishId;

  /// The title of the completed Wish — the text the Celebration View shows to
  /// identify the fulfilled Wish (R7.3).
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CelebrationEvent &&
          other.wishId == wishId &&
          other.title == title;

  @override
  int get hashCode => Object.hash(wishId, title);

  @override
  String toString() => 'CelebrationEvent(wishId: $wishId, title: $title)';
}

/// Watches Wish lifecycle transitions and emits one [CelebrationEvent] per
/// completion.
///
/// The controller is notified of transitions through
/// [notifyTransition] / [notifyResult]; it decides whether a celebration is
/// due and, if so, publishes a [CelebrationEvent] on the [events] stream. The
/// most recent event is also retained as [lastEvent] so late subscribers (or
/// a widget rebuilt after the fact) can read it.
///
/// The controller owns a broadcast [StreamController]; call [dispose] (wired
/// through Riverpod's `onDispose`) to release it.
class CelebrationController {
  CelebrationController();

  final StreamController<CelebrationEvent> _controller =
      StreamController<CelebrationEvent>.broadcast();

  /// The most recently emitted [CelebrationEvent], or `null` if none has fired
  /// yet.
  CelebrationEvent? get lastEvent => _lastEvent;
  CelebrationEvent? _lastEvent;

  /// A broadcast stream of celebration events. Each `→Completed` transition
  /// produces exactly one event here.
  Stream<CelebrationEvent> get events => _controller.stream;

  /// Observes a transition from [before] to [after] for the same Wish and
  /// emits a [CelebrationEvent] iff this is the edge into `Completed`:
  /// `after.status == completed` AND `before.status != completed`.
  ///
  /// Returns the emitted event, or `null` when no celebration was due. Passing
  /// `before == null` treats the Wish as newly observed with no prior
  /// completed state, so a Wish observed already `Completed` for the first
  /// time still celebrates once.
  CelebrationEvent? notifyTransition(Wish? before, Wish after) {
    final bool wasCompleted = before?.status == LifecycleStatus.completed;
    final bool isCompleted = after.status == LifecycleStatus.completed;
    if (isCompleted && !wasCompleted) {
      return _emit(CelebrationEvent.forWish(after));
    }
    return null;
  }

  /// Convenience for the common mutation path where only the resulting [Wish]
  /// and its [previousStatus] are known (for example the value returned by a
  /// repository `transition`/`applyProgress` call alongside the status it had
  /// beforehand).
  ///
  /// Emits a [CelebrationEvent] iff `result.status == completed` and
  /// [previousStatus] was not already `completed`. Returns the emitted event
  /// or `null`.
  CelebrationEvent? notifyResult(
    LifecycleStatus previousStatus,
    Wish result,
  ) {
    final bool wasCompleted = previousStatus == LifecycleStatus.completed;
    final bool isCompleted = result.status == LifecycleStatus.completed;
    if (isCompleted && !wasCompleted) {
      return _emit(CelebrationEvent.forWish(result));
    }
    return null;
  }

  CelebrationEvent _emit(CelebrationEvent event) {
    _lastEvent = event;
    if (!_controller.isClosed) {
      _controller.add(event);
    }
    return event;
  }

  /// Closes the underlying broadcast stream. Idempotent.
  void dispose() {
    if (!_controller.isClosed) {
      unawaited(_controller.close());
    }
  }
}

/// Provides the singleton [CelebrationController] for the application.
///
/// The presentation layer watches [CelebrationController.events] to drive the
/// Celebration View overlay; mutation controllers notify it of lifecycle
/// transitions. The controller is disposed with the provider so its stream is
/// released on teardown.
final Provider<CelebrationController> celebrationControllerProvider =
    Provider<CelebrationController>(
  (Ref ref) {
    final CelebrationController controller = CelebrationController();
    ref.onDispose(controller.dispose);
    return controller;
  },
  name: 'celebrationControllerProvider',
);
