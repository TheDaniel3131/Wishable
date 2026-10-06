/// Application layer — Riverpod providers and controllers (view-models).
///
/// Layering discipline (design "Module boundaries"):
///   - MAY depend on: Domain, Data-Access (via interfaces only).
///   - MUST NOT depend on: Drift-generated types directly.
///
/// Controllers (WishListController, WishEditController, WishActionController,
/// CelebrationController, BackupController) are added by later tasks (11).
library wishable.application;

export 'account/account.dart';
export 'auth/auth.dart';
export 'controllers/backup_controller.dart';
export 'controllers/celebration_controller.dart';
export 'controllers/wish_action_controller.dart';
export 'controllers/wish_edit_controller.dart';
export 'controllers/wish_image_controller.dart';
export 'controllers/wish_list_controller.dart';
export 'providers.dart';
