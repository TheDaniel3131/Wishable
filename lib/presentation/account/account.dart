/// Presentation-layer account barrel (auth spec, Option B).
///
/// The [AccountView] (sign-in/up/out, shown from Settings) and the
/// [SyncStatusIndicator]. Depends only on the application layer and pure domain
/// account types; never imports the backend SDK.
library wishable.presentation.account;

export 'account_view.dart';
export 'sync_status_indicator.dart';
