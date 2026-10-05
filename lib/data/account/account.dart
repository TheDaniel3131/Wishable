/// Data-layer account barrel (auth spec, Option B).
///
/// Exposes the backend-agnostic [AccountAuthService] and [SyncService]
/// interfaces (and their shared value types). The concrete PocketBase adapter
/// under `remote/` is the only importer of the backend SDK; it is wired at the
/// composition root, not re-exported here, so the offline-first test can assert
/// the local graph never imports the SDK.
library wishable.data.account;

export 'account_auth_service.dart';
export 'sync_service.dart';
