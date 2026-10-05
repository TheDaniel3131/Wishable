/// Pure domain validation for [Wish] creation and editing.
///
/// [WishValidator] is the single source of truth for the input-shape rules the
/// design assigns to the domain validator:
///
///   - A title must contain at least one non-whitespace character
///     (R1.2, R2.2); otherwise [TitleRequiredError].
///   - A priority must be a member of the [Priority] set (R4.3); otherwise
///     [InvalidPriorityError].
///   - A progress value must lie in the inclusive range [0, 100] (R5.1, R5.2);
///     otherwise [ProgressOutOfRangeError].
///
/// It also applies the default priority [Priority.medium] when a [WishDraft]
/// omits one (R1.4).
///
/// The validator never throws for invalid *input*; instead it returns a
/// [ValidationResult] describing success or the specific [ValidationError]s.
/// This keeps the application layer in control of how errors surface in the UI
/// (e.g. inline "A title is required" messages) while leaving the stored state
/// untouched on rejection.
///
/// Pure Dart: no Flutter, Drift, or dart:io dependencies.
library wishable.domain.wish_validator;

import 'priority.dart';
import 'wish_input.dart';

/// The lowest valid [Wish] progress value (R5.1).
const int kMinProgress = 0;

/// The highest valid [Wish] progress value (R5.1).
const int kMaxProgress = 100;

/// The priority applied when a [WishDraft] omits one (R1.4).
const Priority kDefaultPriority = Priority.medium;

/// Base type for every validation failure produced by [WishValidator].
///
/// Sealed so callers can exhaustively `switch` over the failure kinds and the
/// analyzer verifies every case is handled.
sealed class ValidationError {
  const ValidationError();

  /// A human-readable description of the failure, suitable for surfacing to the
  /// User (the application layer decides where/how to display it).
  String get message;
}

/// The submitted title was empty or consisted solely of whitespace (R1.2,
/// R2.2).
///
/// All instances are interchangeable and compare equal.
final class TitleRequiredError extends ValidationError {
  const TitleRequiredError();

  @override
  String get message => 'A title is required.';

  @override
  bool operator ==(Object other) => other is TitleRequiredError;

  @override
  int get hashCode => (TitleRequiredError).hashCode;

  @override
  String toString() => 'TitleRequiredError()';
}

/// A supplied priority was not a member of the [Priority] set (R4.3).
///
/// In Dart the [Priority] enum is closed, so this guards boundaries where a
/// priority may arrive as an out-of-range index or an unrecognized token
/// (for example during import/parse).
final class InvalidPriorityError extends ValidationError {
  const InvalidPriorityError([this.token]);

  /// The offending value as received (e.g. an index or raw token), when known.
  final Object? token;

  @override
  String get message => token == null
      ? 'Priority must be one of: Low, Medium, High.'
      : 'Invalid priority "$token"; must be one of: Low, Medium, High.';

  @override
  bool operator ==(Object other) =>
      other is InvalidPriorityError && other.token == token;

  @override
  int get hashCode => Object.hash(InvalidPriorityError, token);

  @override
  String toString() => 'InvalidPriorityError($token)';
}

/// A supplied progress value fell outside the inclusive range [0, 100] (R5.2).
final class ProgressOutOfRangeError extends ValidationError {
  const ProgressOutOfRangeError(this.value);

  /// The rejected progress value.
  final int value;

  @override
  String get message =>
      'Progress must be between $kMinProgress and $kMaxProgress inclusive; '
      'got $value.';

  @override
  bool operator ==(Object other) =>
      other is ProgressOutOfRangeError && other.value == value;

  @override
  int get hashCode => Object.hash(ProgressOutOfRangeError, value);

  @override
  String toString() => 'ProgressOutOfRangeError($value)';
}

/// The outcome of validating an input, carrying either a validated [value] or
/// the list of [errors] that caused rejection.
///
/// A result is a success exactly when [errors] is empty, in which case [value]
/// is non-null. On failure [value] is `null` and [errors] holds one or more
/// [ValidationError]s. This mirrors the design's rule that rejected input
/// leaves stored state unchanged: the caller gets no validated value to
/// persist.
final class ValidationResult<T> {
  const ValidationResult._(this.value, this.errors);

  /// Builds a successful result wrapping [value].
  const ValidationResult.success(T value) : this._(value, const []);

  /// Builds a failed result from a non-empty list of [errors].
  ValidationResult.failure(List<ValidationError> errors)
      : this._(null, List.unmodifiable(_requireNonEmpty(errors)));

  /// The validated value on success, or `null` on failure.
  final T? value;

  /// The validation errors; empty on success, non-empty on failure.
  final List<ValidationError> errors;

  /// Whether validation succeeded (no errors).
  bool get isValid => errors.isEmpty;

  static List<ValidationError> _requireNonEmpty(List<ValidationError> errors) {
    if (errors.isEmpty) {
      throw ArgumentError.value(
        errors,
        'errors',
        'A failed ValidationResult requires at least one error.',
      );
    }
    return errors;
  }

  @override
  String toString() =>
      isValid ? 'ValidationResult.success($value)' : 'ValidationResult.failure($errors)';
}

/// Stateless, pure validator for Wish input types.
///
/// All methods are side-effect free and depend only on Dart core, so they can
/// be exhaustively property-tested (design Properties 2, 3, 8).
final class WishValidator {
  const WishValidator();

  /// Returns `true` when [title] contains at least one non-whitespace
  /// character (R1.2, R2.2).
  bool isTitleValid(String title) => title.trim().isNotEmpty;

  /// Returns `true` when [progress] lies in the inclusive range [0, 100]
  /// (R5.1, R5.2).
  bool isProgressInRange(int progress) =>
      progress >= kMinProgress && progress <= kMaxProgress;

  /// Validates a title in isolation.
  ///
  /// On success the returned value is the title with leading/trailing
  /// whitespace trimmed; on failure the sole error is [TitleRequiredError]
  /// (R1.2, R2.2).
  ValidationResult<String> validateTitle(String title) {
    if (!isTitleValid(title)) {
      return ValidationResult.failure(const [TitleRequiredError()]);
    }
    return ValidationResult.success(title.trim());
  }

  /// Validates a progress value in isolation (R5.1, R5.2).
  ValidationResult<int> validateProgress(int progress) {
    if (!isProgressInRange(progress)) {
      return ValidationResult.failure([ProgressOutOfRangeError(progress)]);
    }
    return ValidationResult.success(progress);
  }

  /// Resolves a [Priority] from an enum index, enforcing set membership (R4.3).
  ///
  /// Used at boundaries (such as import/parse) where a priority may arrive as a
  /// raw integer index. An index outside the [Priority] value range yields
  /// [InvalidPriorityError].
  ValidationResult<Priority> validatePriorityIndex(int index) {
    if (index < 0 || index >= Priority.values.length) {
      return ValidationResult.failure([InvalidPriorityError(index)]);
    }
    return ValidationResult.success(Priority.values[index]);
  }

  /// Resolves a [Priority] from a lowercase token (`low`/`medium`/`high`),
  /// enforcing set membership (R4.3).
  ///
  /// Matching is case-insensitive and trims surrounding whitespace. An
  /// unrecognized token yields [InvalidPriorityError].
  ValidationResult<Priority> validatePriorityToken(String token) {
    final normalized = token.trim().toLowerCase();
    for (final priority in Priority.values) {
      if (priority.name == normalized) {
        return ValidationResult.success(priority);
      }
    }
    return ValidationResult.failure([InvalidPriorityError(token)]);
  }

  /// Validates a [WishDraft] for creation.
  ///
  /// Enforces a non-empty title (R1.2) and applies the default priority
  /// [Priority.medium] when the draft omits one (R1.4). On success the returned
  /// draft has its title trimmed and its priority resolved to a concrete value.
  /// On failure the result carries every applicable error (currently only the
  /// title rule, since an omitted priority is defaulted rather than rejected
  /// and a supplied priority is already a valid [Priority]).
  ValidationResult<WishDraft> validateDraft(WishDraft draft) {
    final errors = <ValidationError>[];
    if (!isTitleValid(draft.title)) {
      errors.add(const TitleRequiredError());
    }
    if (errors.isNotEmpty) {
      return ValidationResult.failure(errors);
    }
    return ValidationResult.success(
      draft.copyWith(
        title: draft.title.trim(),
        priority: draft.priority ?? kDefaultPriority,
      ),
    );
  }

  /// Validates a [WishEdit] for an existing Wish.
  ///
  /// Enforces a non-empty title (R2.2); the priority on a [WishEdit] is a
  /// non-nullable [Priority] and is therefore always a valid set member (R4.3).
  /// On success the returned edit has its title trimmed. On failure the stored
  /// Wish is left unchanged by the caller.
  ValidationResult<WishEdit> validateEdit(WishEdit edit) {
    final errors = <ValidationError>[];
    if (!isTitleValid(edit.title)) {
      errors.add(const TitleRequiredError());
    }
    if (errors.isNotEmpty) {
      return ValidationResult.failure(errors);
    }
    return ValidationResult.success(edit.copyWith(title: edit.title.trim()));
  }
}
