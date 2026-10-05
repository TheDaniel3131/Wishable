// Feature: wishable, Property 5: Category get-or-create is idempotent
//
// Property-based test for DriftCategoryRepository.getOrCreateByName (task 8.9).
//
// Validates: Requirements 3.3
//
// For any category name:
//   * Calling getOrCreateByName(name) twice returns a Category with the same
//     id (the second call reuses the first, never minting a new one).
//   * The total category count increases by exactly one per distinct new name,
//     and not at all on repeated calls with the same name (no duplicates).
//   * The five preset categories (Learn, Travel, Buy, Save, Achieve) are
//     returned as-is — reusing the seeded preset row with isPreset == true —
//     without creating any duplicate.
//
// Each Glados property runs a minimum of 100 generated cases (glados default
// is 100).
library;

import 'package:drift/native.dart';
import 'package:glados/glados.dart';
import 'package:wishable/data/app_database.dart';
import 'package:wishable/data/repositories/drift_category_repository.dart';
import 'package:wishable/domain/category.dart';

/// The five preset category names seeded by the migration (R3.2).
const List<String> _presetNames = <String>[
  'Learn',
  'Travel',
  'Buy',
  'Save',
  'Achieve',
];

/// Generates non-empty category names.
///
/// A guaranteed-non-empty letter core keeps names valid (an empty name is not
/// a meaningful category label), while optional surrounding content exercises
/// a variety of distinct names so new-category creation is well covered.
Generator<String> get _categoryNames => any.combine2(
      any.nonEmptyLetters,
      any.letters,
      (String core, String tail) => '$core$tail',
    );

/// Returns the current number of category rows in [db].
Future<int> _categoryCount(AppDatabase db) async {
  final List<CategoryRow> rows = await db.select(db.categories).get();
  return rows.length;
}

void main() {
  group('get-or-create is idempotent for new user categories', () {
    Glados<String>(_categoryNames).test(
      'two calls with the same name return the same id and add exactly one row',
      (String name) async {
        final AppDatabase db =
            AppDatabase.forExecutor(NativeDatabase.memory());
        final DriftCategoryRepository repo = DriftCategoryRepository(db);
        try {
          final int before = await _categoryCount(db);

          final Category first = await repo.getOrCreateByName(name);
          final int afterFirst = await _categoryCount(db);

          final Category second = await repo.getOrCreateByName(name);
          final int afterSecond = await _categoryCount(db);

          // Same id on both calls: the second reuses the first (R3.3).
          expect(second.id, equals(first.id));
          expect(second, equals(first));
          expect(first.name, equals(name));

          // A brand-new name is a preset only if it collided with a seeded
          // name; otherwise it is a user category.
          final bool isPresetName = _presetNames.contains(name);
          expect(first.isPreset, equals(isPresetName));

          if (isPresetName) {
            // Reused an existing preset: count never changed.
            expect(afterFirst, equals(before));
          } else {
            // Exactly one new row was added by the first call.
            expect(afterFirst, equals(before + 1));
          }

          // The second call never creates a duplicate.
          expect(afterSecond, equals(afterFirst));
        } finally {
          await db.close();
        }
      },
    );
  });

  group('distinct new names each add exactly one row', () {
    Glados<List<String>>(
      any.listWithLengthInRange(0, 8, _categoryNames),
    ).test(
      'count grows by the number of distinct non-preset names, no duplicates',
      (List<String> names) async {
        final AppDatabase db =
            AppDatabase.forExecutor(NativeDatabase.memory());
        final DriftCategoryRepository repo = DriftCategoryRepository(db);
        try {
          final int before = await _categoryCount(db);

          final Map<String, String> idsByName = <String, String>{};
          for (final String name in names) {
            final Category category = await repo.getOrCreateByName(name);
            final String? seenId = idsByName[name];
            if (seenId != null) {
              // Repeated name within the batch must reuse the same id.
              expect(category.id, equals(seenId));
            } else {
              idsByName[name] = category.id;
            }
          }

          final int after = await _categoryCount(db);

          // Only distinct names that are not already-seeded presets create a
          // new row; everything else reuses an existing row (R3.3).
          final Set<String> distinct = names.toSet();
          final int newRows = distinct
              .where((String n) => !_presetNames.contains(n))
              .length;
          expect(after, equals(before + newRows));

          // Every stored id is unique: no duplicate categories were created.
          final List<CategoryRow> rows = await db.select(db.categories).get();
          final Set<String> allIds =
              rows.map((CategoryRow r) => r.id).toSet();
          expect(allIds, hasLength(rows.length));
          final Set<String> allNames =
              rows.map((CategoryRow r) => r.name).toSet();
          expect(allNames, hasLength(rows.length));
        } finally {
          await db.close();
        }
      },
    );
  });

  group('preset categories are returned as-is without duplicating', () {
    Glados<String>(any.choose(_presetNames)).test(
      'get-or-create on a preset reuses the seeded row and adds no rows',
      (String presetName) async {
        final AppDatabase db =
            AppDatabase.forExecutor(NativeDatabase.memory());
        final DriftCategoryRepository repo = DriftCategoryRepository(db);
        try {
          final int before = await _categoryCount(db);
          expect(before, equals(_presetNames.length));

          final Category first = await repo.getOrCreateByName(presetName);
          final Category second = await repo.getOrCreateByName(presetName);

          // The seeded preset is returned unchanged (R3.2, R3.3).
          expect(first.name, equals(presetName));
          expect(first.isPreset, isTrue);
          expect(second.id, equals(first.id));
          expect(second, equals(first));

          // No new rows were ever created for a preset name.
          final int after = await _categoryCount(db);
          expect(after, equals(before));

          // The row count still exactly matches the five seeded presets.
          expect(after, equals(_presetNames.length));
        } finally {
          await db.close();
        }
      },
    );
  });
}
