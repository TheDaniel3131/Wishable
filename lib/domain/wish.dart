/// The [Wish] domain value object — the central record of the application.
///
/// A Wish represents a single aspiration to do, own, experience, or achieve
/// something (design "Domain model"). It carries a stable UUID [id] (R14.1),
/// a non-empty [title] (R1.2), an optional [description] (R1.3), a
/// [categoryId] foreign key (R3.1), a [priority] (R4), a lifecycle [status]
/// (R6), an integer [progress] in the range [0, 100] (R5), and UTC
/// creation/last-modified timestamps (R1.5, R2.4, R14.2).
///
/// Pure Dart: no Flutter, Drift, or dart:io dependencies. Immutable and
/// compared by value.
library wishable.domain.wish;

import 'lifecycle_status.dart';
import 'priority.dart';

/// Sentinel used by [Wish.copyWith] to tell "argument omitted" apart from
/// "explicitly set to null" for the nullable [Wish.description] field.
const Object _unset = Object();

/// An immutable Wish value object.
///
/// Two Wishes are equal when every domain field matches: [id], [title],
/// [description], [categoryId], [priority], [status], [progress],
/// [createdAtUtc], and [updatedAtUtc].
final class Wish {
  const Wish({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.priority,
    required this.status,
    required this.progress,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.seq,
  });

  /// Stable UUID v4 primary key, assigned at creation and never changed on
  /// edit (R14.1).
  final String id;

  /// Non-empty title (R1.2).
  final String title;

  /// Optional free-text description (R1.3). `null` when the user supplied none.
  final String? description;

  /// Foreign key referencing the owning [Category] (R3.1).
  final String categoryId;

  /// Priority ranking; defaults to [Priority.medium] on creation (R1.4).
  final Priority priority;

  /// Lifecycle status; starts at [LifecycleStatus.active] on creation (R1.1).
  final LifecycleStatus status;

  /// Percentage completion in the inclusive range [0, 100] (R5.1).
  final int progress;

  /// Creation timestamp, recorded in UTC (R1.5, R14.2).
  final DateTime createdAtUtc;

  /// Last-modified timestamp, recorded in UTC (R2.4, R14.2).
  final DateTime updatedAtUtc;

  /// Stable, DB-assigned display number ("Wish #N"). Assigned once at creation
  /// and never changed, so it survives reordering and filtering. `null` for a
  /// Wish not yet persisted (e.g. a draft before `create`).
  final int? seq;

  /// Returns a copy of this Wish with the given fields replaced.
  ///
  /// Omitted arguments retain their current value. [description] is nullable,
  /// so a sentinel distinguishes "omitted" (keep current) from an explicit
  /// `null` (clear the description): pass `description: null` to clear it.
  Wish copyWith({
    String? id,
    String? title,
    Object? description = _unset,
    String? categoryId,
    Priority? priority,
    LifecycleStatus? status,
    int? progress,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    int? seq,
  }) {
    return Wish(
      id: id ?? this.id,
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      seq: seq ?? this.seq,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wish &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.categoryId == categoryId &&
          other.priority == priority &&
          other.status == status &&
          other.progress == progress &&
          other.createdAtUtc == createdAtUtc &&
          other.updatedAtUtc == updatedAtUtc &&
          other.seq == seq;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        categoryId,
        priority,
        status,
        progress,
        createdAtUtc,
        updatedAtUtc,
        seq,
      );

  @override
  String toString() => 'Wish(id: $id, title: $title, '
      'description: $description, categoryId: $categoryId, '
      'priority: $priority, status: $status, progress: $progress, '
      'createdAtUtc: $createdAtUtc, updatedAtUtc: $updatedAtUtc, seq: $seq)';
}
