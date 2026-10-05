/// The [WishActionController] — the application-layer view-model that drives
/// per-Wish actions (design "Controllers (view-models)" row
/// `WishActionController`).
///
/// It owns the imperative, single-Wish mutations the UI triggers from a Wish
/// card or detail view:
///
///   - progress updates (R5.1–R5.4),
///   - lifecycle transitions — start, complete, reopen (R6.2–R6.4),
///   - delete-with-confirmation (R8.1–R8.3).
///
/// Every mutation is routed through the [WishRepository] interface obtained
/// from [wishRepositoryProvider], so this controller depends only on the
/// Drift-free data-access seam and the domain types ([Wish], [WishId],
/// [LifecycleEvent] and friends) — never on Drift (design R14.3, "Module
/// boundaries").
///
/// ## Delete-with-confirmation (R8)
///
/// Deletion is a two-step, confirmation-gated operation. The UI first calls
/// [requestDelete] when the User asks to delete a Wish (R8.2); that returns a
/// [DeleteRequest] describing what is about to be removed but performs no
/// repository call. The UI then shows a confirmation dialog and either:
///
///   - calls [confirmDelete] with the request, which removes the Wish from the
///     Local_Database (R8.1); or
///   - calls [cancelDelete] (or simply does nothing), which is a pure no-op —
///     no repository call, no state change — so the Wish is retained (R8.3).
///
/// ## Completion celebration (R7)
///
/// A transition whose resulting [Wish.status] is [LifecycleStatus.completed]
/// should raise the celebration. That is the job of `CelebrationController`;
/// this controller detects the before/after transition and hands it off via
/// [CelebrationController.notifyTransition]. The resulting Wish is still
/// returned so callers can react immediately.
library wishable.application.controllers.wish_action_controller;

import 'package:riverpod/riverpod.dart';

import '../../data/repositories/wish_repository.dart';
import '../../domain/ids.dart';
import '../../domain/lifecycle_event.dart';
import '../../domain/lifecycle_status.dart';
import '../../domain/wish.dart';
import '../providers.dart';
import 'celebration_controller.dart';

/// Describes a pending, not-yet-confirmed deletion of a single Wish.
///
/// Produced by [WishActionController.requestDelete] and consumed by
/// [WishActionController.confirmDelete]. Carrying the [id] and a human-readable
/// [title] lets the confirmation UI name the Wish it is about to remove without
/// a second read, while keeping the request itself inert — constructing one
/// touches no storage (R8.2).
final class DeleteRequest {
  const DeleteRequest({required this.id, required this.title});

  /// The id of the Wish the User asked to delete.
  final WishId id;

  /// The title of the Wish, for display in the confirmation prompt.
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeleteRequest && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() => 'DeleteRequest(id: $id, title: $title)';
}

/// Drives progress updates, lifecycle transitions, and delete-with-confirmation
/// for a single Wish at a time.
///
/// The controller is stateless beyond the injected [Ref]; each action reads the
/// current [WishRepository] and awaits the resulting [Wish] (or `void` for a
/// confirmed delete). It is exposed through [wishActionControllerProvider].
final class WishActionController {
  WishActionController(this._ref);

  final Ref _ref;

  /// The current repository, resolved through the interface-typed provider so
  /// no Drift type is observed here (R14.3).
  WishRepository get _repository => _ref.read(wishRepositoryProvider);

  /// Sets the progress of the Wish identified by [id] to [value], routed
  /// through the repository (and thus the lifecycle policy): a move from 0 to a
  /// value above 0 implies `In_Progress` and a value of 100 implies `Completed`
  /// (R5.1–R5.4). Returns the resulting [Wish].
  ///
  /// If the update completes the Wish, the celebration is handed off the same
  /// way lifecycle transitions are (see [_notifyIfCompleted]).
  Future<Wish> applyProgress(WishId id, int value) async {
    final Wish before = await _repository.getById(id) ?? await _notFound(id);
    final Wish after = await _repository.applyProgress(id, value);
    _notifyIfCompleted(before: before, after: after);
    return after;
  }

  /// Marks the `Active` Wish identified by [id] as started, moving it to
  /// `In_Progress` (R6.2). Returns the resulting [Wish].
  Future<Wish> start(WishId id) => _transition(id, const StartEvent());

  /// Marks the Wish identified by [id] as complete, forcing status to
  /// `Completed` and progress to 100 (R6.3). Returns the resulting [Wish].
  Future<Wish> complete(WishId id) => _transition(id, const CompleteEvent());

  /// Reopens the `Completed` Wish identified by [id], moving it back to
  /// `In_Progress` while retaining its stored progress (R6.4). Returns the
  /// resulting [Wish].
  Future<Wish> reopen(WishId id) => _transition(id, const ReopenEvent());

  /// Begins a confirmation-gated deletion for the Wish identified by [id]
  /// (R8.2).
  ///
  /// This performs NO repository call: it reads the current Wish only to label
  /// the confirmation prompt and returns a [DeleteRequest] the UI passes to
  /// [confirmDelete] once the User confirms. Returns `null` if no Wish with
  /// [id] exists, so there is nothing to confirm.
  Future<DeleteRequest?> requestDelete(WishId id) async {
    final Wish? wish = await _repository.getById(id);
    if (wish == null) {
      return null;
    }
    return DeleteRequest(id: wish.id, title: wish.title);
  }

  /// Confirms and executes a pending deletion, removing the Wish from the
  /// Local_Database (R8.1).
  ///
  /// Call this only after the User confirms the [request] produced by
  /// [requestDelete].
  Future<void> confirmDelete(DeleteRequest request) {
    return _repository.delete(request.id);
  }

  /// Cancels a pending deletion. This is a pure no-op: it issues no repository
  /// call and changes no state, so the Wish is retained in the Local_Database
  /// (R8.3). The [request] is accepted for symmetry with [confirmDelete] and
  /// call-site clarity; it is intentionally unused.
  void cancelDelete(DeleteRequest request) {
    // No-op by design (R8.3): cancelling a delete request must not touch
    // storage or mutate any state.
  }

  /// Applies [event] to the Wish identified by [id] through the repository
  /// (and thus the lifecycle policy), returning the resulting [Wish] and
  /// handing off to the celebration when the result is `Completed`.
  Future<Wish> _transition(WishId id, LifecycleEvent event) async {
    final Wish before = await _repository.getById(id) ?? await _notFound(id);
    final Wish after = await _repository.transition(id, event);
    _notifyIfCompleted(before: before, after: after);
    return after;
  }

  /// Hands a completed transition off to the celebration.
  ///
  /// Fires only on the edge INTO `Completed` — i.e. when [after] is
  /// `Completed` and [before] was not — so re-completing an already-completed
  /// Wish (e.g. a progress write at 100) does not raise a duplicate
  /// celebration (R7.1).
  void _notifyIfCompleted({required Wish before, required Wish after}) {
    final bool justCompleted = after.status == LifecycleStatus.completed &&
        before.status != LifecycleStatus.completed;
    if (!justCompleted) {
      return;
    }
    // Hand the before/after transition off to the CelebrationController so it
    // raises exactly one "Wish fulfilled" event carrying `after.title`
    // (R7.1, R7.3). The resulting Wish is still returned to the caller above so
    // the UI reflects the completion immediately.
    _ref.read(celebrationControllerProvider).notifyTransition(before, after);
  }

  /// Signals that no Wish with [id] exists for a mutation that requires one.
  Future<Never> _notFound(WishId id) {
    return Future<Never>.error(
      StateError('No Wish found with id "$id".'),
    );
  }
}

/// Provides the [WishActionController], wired to the current [Ref] so it can
/// resolve [wishRepositoryProvider] (and, later, the celebration controller) at
/// action time.
final Provider<WishActionController> wishActionControllerProvider =
    Provider<WishActionController>(
  WishActionController.new,
  name: 'wishActionControllerProvider',
);
