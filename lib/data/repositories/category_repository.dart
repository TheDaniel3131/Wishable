/// The [CategoryRepository] abstract interface (design "Data-Access Layer
/// (repositories)").
///
/// Drift-free seam for category persistence: the layers above depend only on
/// this interface, a Drift-backed class (task 8.3) implements it, and the
/// interface references only the domain [Category] type so no Drift type
/// leaks across the boundary (R14.3).
library wishable.data.repositories.category_repository;

import '../../domain/category.dart';

/// Reactive, Drift-free persistence boundary for [Category] records.
abstract interface class CategoryRepository {
  /// Returns a one-shot snapshot of all categories (R3).
  Future<List<Category>> getAll();

  /// Returns the existing category with the given [name], or creates one if
  /// none exists. Idempotent: repeated calls with the same name reuse the same
  /// category and never create duplicates (R3.3).
  Future<Category> getOrCreateByName(String name);

  /// Watches every category, emitting a new list whenever the data changes.
  Stream<List<Category>> watchAll();
}
