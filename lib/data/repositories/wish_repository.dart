/// The [WishRepository] abstract interface (design "Data-Access Layer
/// (repositories)").
///
/// This is the Drift-free seam between the data layer and everything above it:
/// the application and presentation layers depend only on this interface, and
/// a Drift-backed class (task 8.2) provides the implementation. The interface
/// references only domain types — [Wish], [WishDraft], [WishEdit], [WishId],
/// [CategoryId], [LifecycleStatus], and [LifecycleEvent] — so no Drift type
/// leaks across the boundary (R14.3).
///
/// Mutating operations return the resulting [Wish] so controllers can react to
/// the new state (e.g. detect a transition to Completed and fire the
/// celebration) without a second read. Read operations are exposed as
/// [Stream]s backed by Drift's reactive queries so list views auto-refresh
/// when the database changes (R9). `getAll`/`replaceAll` give the
/// `BackupService` a Drift-free view of the data for export and restore
/// (R11, R12.1).
library wishable.data.repositories.wish_repository;

import '../../domain/ids.dart';
import '../../domain/lifecycle_event.dart';
import '../../domain/lifecycle_status.dart';
import '../../domain/wish.dart';
import '../../domain/wish_input.dart';

/// Reactive, Drift-free persistence boundary for [Wish] records.
abstract interface class WishRepository {
  /// Creates a new Wish from [draft], assigning a UUID id and UTC timestamps
  /// and starting it Active with progress 0 (R1).
  Future<Wish> create(WishDraft draft);

  /// Applies [edit] to the Wish identified by [id], preserving its id and
  /// updating `updatedAtUtc` (R2).
  Future<Wish> update(WishId id, WishEdit edit);

  /// Deletes the Wish identified by [id] (R8).
  Future<void> delete(WishId id);

  /// Returns the Wish identified by [id], or `null` if none exists (R9.5).
  Future<Wish?> getById(WishId id);

  /// Watches every Wish, emitting a new list whenever the data changes (R9.1).
  Stream<List<Wish>> watchAll();

  /// Watches Wishes with the given lifecycle [status] (R9.2–R9.4, R6.5).
  Stream<List<Wish>> watchByStatus(LifecycleStatus status);

  /// Watches Wishes belonging to the category identified by [id] (R3.4).
  Stream<List<Wish>> watchByCategory(CategoryId id);

  /// Updates the progress of the Wish identified by [id], routed through the
  /// lifecycle policy, and returns the resulting Wish (R5).
  Future<Wish> applyProgress(WishId id, int progress);

  /// Applies a lifecycle [event] to the Wish identified by [id], routed
  /// through the lifecycle policy, and returns the resulting Wish (R6).
  Future<Wish> transition(WishId id, LifecycleEvent event);

  /// Returns a one-shot snapshot of all Wishes for export (R11).
  Future<List<Wish>> getAll();

  /// Replaces all Wishes with [wishes] inside a single transaction for
  /// restore (R12.1).
  Future<void> replaceAll(List<Wish> wishes);
}
