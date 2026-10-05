/// Application-layer account barrel (auth spec, Option B).
///
/// Exposes the [AccountController] + [SyncController] and the interface-typed
/// providers. Depends only on the Drift-free, SDK-free interfaces from the data
/// barrel and the pure domain account types — except the providers file, which
/// is the composition seam that binds the concrete PocketBase adapters.
library wishable.application.account;

export 'account_controller.dart';
export 'account_providers.dart';
export 'sync_controller.dart';
