/// Account domain barrel (auth spec, Option B).
///
/// Pure Dart identity + session + sync-state types shared by the account/sync
/// controllers and the backend adapter. No Flutter, no backend SDK.
library wishable.domain.account;

export 'account.dart';
export 'account_session.dart';
export 'sync_merge.dart';
export 'sync_state.dart';
