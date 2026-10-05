/// The sync status surfaced to the UI (auth spec, Option B — R12).
///
/// Pure domain type exposed by the application layer's `SyncController`. Drives
/// a small status affordance (idle / syncing / offline / error). Sync converges
/// the local Drift database with the backend using last-write-wins by
/// `updatedAtUtc` and a tombstone rule for delete-vs-edit (see the design).
library wishable.domain.account.sync_state;

/// Base type for sync status. Sealed for exhaustive handling.
sealed class SyncState {
  const SyncState();
}

/// Not currently syncing; the local database is the working copy (R12.3).
final class SyncIdle extends SyncState {
  const SyncIdle({this.lastSyncedUtc});

  /// When the last successful sync completed, or null if never.
  final DateTime? lastSyncedUtc;

  @override
  bool operator ==(Object other) =>
      other is SyncIdle && other.lastSyncedUtc == lastSyncedUtc;
  @override
  int get hashCode => Object.hash(SyncIdle, lastSyncedUtc);
}

/// A push/pull cycle is in progress (R12.1).
final class Syncing extends SyncState {
  const Syncing();

  @override
  bool operator ==(Object other) => other is Syncing;
  @override
  int get hashCode => (Syncing).hashCode;
}

/// The device is offline; changes accumulate locally and sync later (R12.3).
final class SyncOffline extends SyncState {
  const SyncOffline();

  @override
  bool operator ==(Object other) => other is SyncOffline;
  @override
  int get hashCode => (SyncOffline).hashCode;
}

/// A sync attempt failed; the local database is left consistent and sync will
/// retry (R12.4). Carries a non-blocking, user-facing message.
final class SyncError extends SyncState {
  const SyncError(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is SyncError && other.message == message;
  @override
  int get hashCode => Object.hash(SyncError, message);
}
