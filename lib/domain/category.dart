/// The [Category] domain value object.
///
/// A Category is a grouping label applied to a [Wish] (design R3.1). The five
/// preset categories (Learn, Travel, Buy, Save, Achieve) are seeded by the
/// database migration with [isPreset] set to `true` (R3.2); user-created
/// categories have [isPreset] `false`. Names are unique so get-or-create can
/// be idempotent (R3.3).
///
/// Pure Dart: no Flutter, Drift, or dart:io dependencies.
library wishable.domain.category;

/// An immutable category value object.
///
/// Compared by value: two Categories are equal when their [id], [name], and
/// [isPreset] all match.
final class Category {
  const Category({
    required this.id,
    required this.name,
    this.isPreset = false,
  });

  /// Stable unique identifier (UUID string).
  final String id;

  /// Display name, unique across all categories (R3.3).
  final String name;

  /// Whether this is one of the seeded preset categories (R3.2).
  final bool isPreset;

  /// Returns a copy of this Category with the given fields replaced.
  ///
  /// Omitted fields retain their current value. Because [name] and [id] are
  /// non-nullable there is no need for sentinel handling here.
  Category copyWith({
    String? id,
    String? name,
    bool? isPreset,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      isPreset: isPreset ?? this.isPreset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          other.id == id &&
          other.name == name &&
          other.isPreset == isPreset;

  @override
  int get hashCode => Object.hash(id, name, isPreset);

  @override
  String toString() =>
      'Category(id: $id, name: $name, isPreset: $isPreset)';
}
