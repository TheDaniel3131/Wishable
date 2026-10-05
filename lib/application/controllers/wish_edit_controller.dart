/// [WishEditController] — the create/edit view-model (design "Application
/// Layer", task 11.3).
///
/// This controller owns the "save a Wish" use case for both creating a new
/// Wish from a [WishDraft] (R1) and editing an existing one via a [WishEdit]
/// (R2). It runs the pure [WishValidator] over the input and only then calls
/// the data layer:
///
///   - on success it persists through [WishRepository.create] (R1.1, R4.1) or
///     [WishRepository.update] (R2.1, R2.3), both reached through the
///     interface-typed [wishRepositoryProvider];
///   - on validation failure it does NOT throw — it surfaces the specific
///     [ValidationError]s ([TitleRequiredError] for a blank title (R1.2),
///     [InvalidPriorityError] for an out-of-set priority (R4.3)) as state so
///     the form can show them inline while leaving stored data untouched.
///
/// The state is an [AsyncValue] wrapping a [WishEditState] so the UI can also
/// reflect the in-flight (saving) and repository-failure cases distinctly from
/// validation failures. Validation failures are a normal, expected outcome and
/// are modelled as *data* ([WishEditInvalid]); only an unexpected repository
/// error flows through [AsyncError].
///
/// Layering discipline: this file references domain types and the
/// [WishRepository] interface (via its provider) only — no Drift types leak in
/// (R14.3).
library wishable.application.controllers.wish_edit_controller;

import 'package:riverpod/riverpod.dart';

import '../../data/repositories/wish_repository.dart';
import '../../domain/domain.dart';
import '../providers.dart';

/// The outcome of a create/edit attempt, held as the controller's data value.
///
/// Sealed so the UI can exhaustively `switch` over the three outcomes:
///   - [WishEditInitial]  — no attempt made yet (nothing to show);
///   - [WishEditInvalid]  — validation rejected the input; carries the errors;
///   - [WishEditSaved]    — the input was persisted; carries the saved [Wish].
sealed class WishEditState {
  const WishEditState();
}

/// No save has been attempted yet. The initial state of the controller.
final class WishEditInitial extends WishEditState {
  const WishEditInitial();

  @override
  bool operator ==(Object other) => other is WishEditInitial;

  @override
  int get hashCode => (WishEditInitial).hashCode;

  @override
  String toString() => 'WishEditInitial()';
}

/// Validation rejected the submitted input (R1.2, R4.3).
///
/// [errors] is the non-empty list of [ValidationError]s the form should show
/// inline (e.g. [TitleRequiredError], [InvalidPriorityError]). No persistence
/// occurred, so stored state is unchanged.
final class WishEditInvalid extends WishEditState {
  WishEditInvalid(List<ValidationError> errors)
      : errors = List.unmodifiable(_requireNonEmpty(errors));

  /// The validation failures to surface inline. Always non-empty.
  final List<ValidationError> errors;

  static List<ValidationError> _requireNonEmpty(List<ValidationError> errors) {
    if (errors.isEmpty) {
      throw ArgumentError.value(
        errors,
        'errors',
        'WishEditInvalid requires at least one validation error.',
      );
    }
    return errors;
  }

  @override
  bool operator ==(Object other) =>
      other is WishEditInvalid && _listEquals(other.errors, errors);

  @override
  int get hashCode => Object.hashAll(errors);

  @override
  String toString() => 'WishEditInvalid($errors)';
}

/// The input was validated and persisted; [wish] is the saved record (R1.1,
/// R2.1).
final class WishEditSaved extends WishEditState {
  const WishEditSaved(this.wish);

  /// The Wish as persisted (freshly created or updated).
  final Wish wish;

  @override
  bool operator ==(Object other) =>
      other is WishEditSaved && other.wish == wish;

  @override
  int get hashCode => wish.hashCode;

  @override
  String toString() => 'WishEditSaved($wish)';
}

bool _listEquals(List<ValidationError> a, List<ValidationError> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// View-model that validates and persists a create or edit of a [Wish].
///
/// Exposed via [wishEditControllerProvider]. The controller starts in
/// [WishEditInitial]; calling [createWish] or [editWish] drives it through a
/// loading state to either [WishEditSaved] (persisted) or [WishEditInvalid]
/// (validation errors to show inline). An unexpected repository failure is
/// surfaced as an [AsyncError] rather than as data.
final class WishEditController extends AutoDisposeAsyncNotifier<WishEditState> {
  static const WishValidator _validator = WishValidator();

  @override
  Future<WishEditState> build() async => const WishEditInitial();

  /// Validates and creates a new Wish from [draft] (R1).
  ///
  /// On validation success the (trimmed, priority-defaulted) draft is persisted
  /// via [WishRepository.create] and the state becomes [WishEditSaved]. On
  /// validation failure no write occurs and the state becomes [WishEditInvalid]
  /// carrying the errors (e.g. [TitleRequiredError]). The validated [Wish] is
  /// returned on success, or `null` when validation failed.
  Future<Wish?> createWish(WishDraft draft) async {
    final ValidationResult<WishDraft> result = _validator.validateDraft(draft);
    if (!result.isValid) {
      state = AsyncData(WishEditInvalid(result.errors));
      return null;
    }

    state = const AsyncLoading<WishEditState>();
    final AsyncValue<WishEditState> next =
        await AsyncValue.guard<WishEditState>(() async {
      final WishRepository repository = ref.read(wishRepositoryProvider);
      final Wish saved = await repository.create(result.value!);
      return WishEditSaved(saved);
    });
    state = next;
    return next.value is WishEditSaved
        ? (next.value! as WishEditSaved).wish
        : null;
  }

  /// Validates and applies [edit] to the Wish identified by [id] (R2).
  ///
  /// On validation success the (trimmed) edit is persisted via
  /// [WishRepository.update], preserving the id and bumping `updatedAtUtc`, and
  /// the state becomes [WishEditSaved]. On validation failure no write occurs,
  /// the stored Wish is left unchanged, and the state becomes [WishEditInvalid]
  /// carrying the errors. The validated [Wish] is returned on success, or
  /// `null` when validation failed.
  Future<Wish?> editWish(WishId id, WishEdit edit) async {
    final ValidationResult<WishEdit> result = _validator.validateEdit(edit);
    if (!result.isValid) {
      state = AsyncData(WishEditInvalid(result.errors));
      return null;
    }

    state = const AsyncLoading<WishEditState>();
    final AsyncValue<WishEditState> next =
        await AsyncValue.guard<WishEditState>(() async {
      final WishRepository repository = ref.read(wishRepositoryProvider);
      final Wish saved = await repository.update(id, result.value!);
      return WishEditSaved(saved);
    });
    state = next;
    return next.value is WishEditSaved
        ? (next.value! as WishEditSaved).wish
        : null;
  }

  /// Resets the controller to [WishEditInitial], clearing any surfaced errors
  /// or prior result (e.g. when the form is reopened for a fresh entry).
  void reset() {
    state = const AsyncData(WishEditInitial());
  }
}

/// Provides the [WishEditController] as an auto-disposing async view-model.
///
/// Auto-dispose so each editor screen gets a fresh controller and its
/// transient validation/saving state does not outlive the form.
final AutoDisposeAsyncNotifierProvider<WishEditController, WishEditState>
    wishEditControllerProvider =
    AsyncNotifierProvider.autoDispose<WishEditController, WishEditState>(
  WishEditController.new,
  name: 'wishEditControllerProvider',
);
