/// Drift-backed implementation of [CategoryRepository] (task 8.3).
///
/// This file lives in the data-access layer — the only layer permitted to
/// reference Drift types (design R14.3). It maps the generated Drift
/// [CategoryRow] to the domain [Category] value object and back, so no Drift
/// type leaks across the repository boundary.
///
/// `getOrCreateByName` is idempotent: it reuses an existing category by its
/// unique [name] and only inserts a new one (with a fresh UUID and
/// `isPreset == false`) when none exists, re-querying on a unique-constraint
/// collision so concurrent callers converge on the same category (R3.3).
library wishable.data.repositories.drift_category_repository;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/category.dart';
import '../app_database.dart';
import 'category_repository.dart';

/// Persists [Category] records in the Drift [AppDatabase].
final class DriftCategoryRepository implements CategoryRepository {
  /// Creates a repository backed by [_db].
  DriftCategoryRepository(this._db);

  final AppDatabase _db;

  static const Uuid _uuid = Uuid();

  @override
  Future<List<Category>> getAll() async {
    final List<CategoryRow> rows = await _db.select(_db.categories).get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Stream<List<Category>> watchAll() {
    return _db
        .select(_db.categories)
        .watch()
        .map((List<CategoryRow> rows) =>
            rows.map(_toDomain).toList(growable: false));
  }

  @override
  Future<Category> getOrCreateByName(String name) async {
    // Reuse an existing category by its unique name if one is present.
    final Category? existing = await _findByName(name);
    if (existing != null) {
      return existing;
    }

    // None found: insert a fresh user category. A concurrent insert could win
    // the race on the UNIQUE(name) constraint, so re-query on failure and
    // return the row that was actually stored — keeping the operation
    // idempotent and duplicate-free (R3.3).
    final Category candidate = Category(
      id: _uuid.v4(),
      name: name,
      isPreset: false,
    );
    try {
      await _db.into(_db.categories).insert(
            CategoriesCompanion.insert(
              id: candidate.id,
              name: candidate.name,
              isPreset: Value(candidate.isPreset),
            ),
          );
      return candidate;
    } on Exception {
      final Category? raced = await _findByName(name);
      if (raced != null) {
        return raced;
      }
      rethrow;
    }
  }

  /// Returns the stored category with exactly [name], or `null` if none exists.
  Future<Category?> _findByName(String name) async {
    final CategoryRow? row = await (_db.select(_db.categories)
          ..where(($CategoriesTable t) => t.name.equals(name))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Maps a Drift [CategoryRow] to the domain [Category].
  static Category _toDomain(CategoryRow row) => Category(
        id: row.id,
        name: row.name,
        isPreset: row.isPreset,
      );
}
