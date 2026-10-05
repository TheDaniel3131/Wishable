/// Presentation layer — Flutter widgets, GoRouter routes, the responsive shell,
/// list/detail/editor views, settings, and the celebration overlay.
///
/// Layering discipline (design "Module boundaries"):
///   - MAY depend on: Application, Domain (read-only models).
///   - MUST NOT depend on: Data-Access, Drift, dart:io.
///
/// Concrete widgets are added by later tasks (12–15). This barrel exists so the
/// layer boundary is present from the first scaffold.
///
/// The GoRouter configuration (task 12.1) is exported here so `main.dart`
/// (task 16) and the responsive shell (task 12.2) can import a single
/// presentation entry point.
library wishable.presentation;

export 'account/account.dart';

export 'auth/auth.dart';

export 'brand/brand.dart';

export 'overlay/celebration_overlay.dart';

export 'router/app_router.dart';

export 'shell/app_shell.dart';

export 'views/settings_view.dart';

export 'views/wish_detail_view.dart';

export 'views/wish_edit_form_view.dart';

export 'views/wish_list_view.dart';
