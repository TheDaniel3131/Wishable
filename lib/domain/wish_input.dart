/// Input value types for creating and editing a [Wish].
///
/// These are the parameter objects taken by the data layer's
/// `WishRepository.create(WishDraft)` and
/// `WishRepository.update(WishId, WishEdit)` (design "Data-Access Layer").
/// They carry only user-supplied fields; the repository assigns the id,
/// timestamps, and initial lifecycle state. Validation (non-empty title,
/// priority membership, progress bounds) is performed by `WishValidator`
/// (task 5), so these types are plain immutable carriers.
///
/// Pure Dart: no Flutter, Drift, or dart:io dependencies.
library wishable.domain.wish_input;

import 'priority.dart';

/// Sentinel used by the `copyWith` methods to tell "argument omitted" apart
/// from "explicitly set to null" for nullable fields.
const Object _unset = Object();

/// Input for creating a new [Wish] (design R1).
///
/// A newly created Wish is always `Active` with progress 0 (R1.1), so those
/// are not part of the draft. When [priority] is omitted the repository
/// applies the default [Priority.medium] (R1.4).
final class WishDraft {
  const WishDraft({
    required this.title,
    this.description,
    required this.categoryId,
    this.priority,
  });

  /// Proposed title. Validated non-empty before persistence (R1.2).
  final String title;

  /// Optional description (R1.3).
  final String? description;

  /// Owning category id (R3.1).
  final String categoryId;

  /// Optional priority; when `null` the default [Priority.medium] is applied
  /// (R1.4).
  final Priority? priority;

  /// Returns a copy of this draft with the given fields replaced.
  ///
  /// [description] and [priority] are nullable, so a sentinel distinguishes
  /// "omitted" (keep current) from an explicit `null` (clear the value).
  WishDraft copyWith({
    String? title,
    Object? description = _unset,
    String? categoryId,
    Object? priority = _unset,
  }) {
    return WishDraft(
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      categoryId: categoryId ?? this.categoryId,
      priority:
          identical(priority, _unset) ? this.priority : priority as Priority?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WishDraft &&
          other.title == title &&
          other.description == description &&
          other.categoryId == categoryId &&
          other.priority == priority;

  @override
  int get hashCode => Object.hash(title, description, categoryId, priority);

  @override
  String toString() => 'WishDraft(title: $title, description: $description, '
      'categoryId: $categoryId, priority: $priority)';
}

/// Input for editing an existing [Wish] (design R2).
///
/// The identity ([id]) and timestamps are owned by the repository: the id is
/// preserved across edits (R14.1) and `updatedAtUtc` is set at save time
/// (R2.4). This type carries the user-editable fields; progress and lifecycle
/// transitions are driven through `applyProgress`/`transition`, not through a
/// bare edit.
final class WishEdit {
  const WishEdit({
    required this.title,
    this.description,
    required this.categoryId,
    required this.priority,
  });

  /// New title. Validated non-empty; an empty title rejects the edit and
  /// leaves the stored Wish unchanged (R2.2).
  final String title;

  /// New description, or `null` to clear it (R2.3).
  final String? description;

  /// New owning category id (R2.3, R3.1).
  final String categoryId;

  /// New priority (R2.3, R4.1).
  final Priority priority;

  /// Returns a copy of this edit with the given fields replaced.
  ///
  /// [description] is nullable, so a sentinel distinguishes "omitted" (keep
  /// current) from an explicit `null` (clear the description).
  WishEdit copyWith({
    String? title,
    Object? description = _unset,
    String? categoryId,
    Priority? priority,
  }) {
    return WishEdit(
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WishEdit &&
          other.title == title &&
          other.description == description &&
          other.categoryId == categoryId &&
          other.priority == priority;

  @override
  int get hashCode => Object.hash(title, description, categoryId, priority);

  @override
  String toString() => 'WishEdit(title: $title, description: $description, '
      'categoryId: $categoryId, priority: $priority)';
}
