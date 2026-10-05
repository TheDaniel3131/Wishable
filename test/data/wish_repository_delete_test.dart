// Feature: wishable, Property 13: Confirmed delete removes exactly the target
//
// Property-based test for task 8.12.
//
// **Property 13: Confirmed delete removes exactly the target**
// **Validates: Requirements 8.1**
//
// For any population of persisted Wishes, deleting one target Wish through the
// Drift-backed [DriftWishRepository.delete] must remove EXACTLY that Wish and
// nothing else:
//
//   - the target is gone: `getById(target)` returns `null` and the target id
//     no longer appears in `getAll()` (R8.1), and
//   - every OTHER Wish survives UNCHANGED: the surviving id set is exactly the
//     original id set minus the target, and each survivor matches the
//     pre-delete record field-for-field (no collateral deletion or mutation).
//
// The population is built against a real Drift [AppDatabase] over an in-memory
// executor (`NativeDatabase.memory()`), so this exercises the actual SQL
// `delete ... where id = ?` in [DriftWishRepository], not a stub. A single
// category is created first to satisfy the Wishes FK (R3.1), and every Wish is
// created through the repository.
//
// The language and framework (Dart property testing via `glados`) follow the
// design's Testing Strategy. glados' `expect`/`test` clash with flutter_test's,
// so those two are hidden and flutter_test provides the runner and matchers.
library wishable.test.data.wish_repository_delete_test;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, test;
import 'package:wishable/data/app_database.dart';
import 'package:wishable/data/repositories/drift_category_repository.dart';
import 'package:wishable/data/repositories/drift_wish_repository.dart';
import 'package:wishable/domain/category.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';
import 'package:wishable/domain/wish_input.dart';

void main() {
  // Required because the test touches the Flutter/Drift native bindings.
  TestWidgetsFlutterBinding.ensureInitialized();

  // 100 generated cases. Each generates a non-empty population plus an index
  // selecting the delete target, run against a fresh in-memory database so the
  // cases stay fully isolated.
  Glados<_DeleteCase>(_anyDeleteCase, ExploreConfig(numRuns: 100)).test(
    'delete() removes exactly the target and leaves every other Wish '
    'unchanged',
    (_DeleteCase testCase) async {
      final AppDatabase db = AppDatabase.forExecutor(NativeDatabase.memory());
      try {
        final wishes = DriftWishRepository(db);
        final categories = DriftCategoryRepository(db);

        // A single category satisfies the Wishes FK (R3.1).
        final Category category =
            await categories.getOrCreateByName('DeleteCategory');

        // Build the population through the repository.
        final List<Wish> created = <Wish>[];
        for (int i = 0; i < testCase.specs.length; i++) {
          final _WishSpec spec = testCase.specs[i];
          created.add(await wishes.create(WishDraft(
            title: spec.title,
            description: spec.description,
            categoryId: category.id,
            priority: spec.priority,
          )));
        }

        // A model of the pre-delete state, computed in the test (not
        // re-derived from the thing under test).
        final Map<String, Wish> before = <String, Wish>{
          for (final Wish w in created) w.id: w,
        };

        // Pick the target deterministically from the generated index.
        final Wish target = created[testCase.targetIndex % created.length];

        // --- the operation under test -----------------------------------
        await wishes.delete(target.id);

        // --- the target is gone -----------------------------------------
        final Wish? deleted = await wishes.getById(target.id);
        expect(deleted, isNull,
            reason: 'getById must return null for the deleted Wish');

        final List<Wish> remaining = await wishes.getAll();
        final Set<String> remainingIds =
            remaining.map((Wish w) => w.id).toSet();
        expect(remainingIds, isNot(contains(target.id)),
            reason: 'the deleted Wish must not appear in getAll()');

        // --- exactly the others remain, each unchanged ------------------
        final Set<String> expectedSurvivorIds = before.keys.toSet()
          ..remove(target.id);
        expect(remainingIds, equals(expectedSurvivorIds),
            reason: 'getAll() must contain exactly the non-target Wishes');
        expect(remaining, hasLength(expectedSurvivorIds.length),
            reason: 'delete must not drop or duplicate any other Wish');

        for (final Wish survivor in remaining) {
          final Wish original = before[survivor.id]!;
          _expectUnchanged(actual: survivor, reference: original);
        }
      } finally {
        await db.close();
      }
    },
  );
}

// --- Unchanged assertion ----------------------------------------------------

/// Asserts a surviving Wish is byte-for-byte the record it was before the
/// delete. The repository returns the created Wish directly (same stored
/// resolution it just wrote), and `getAll()` reads it back, so every field —
/// including the timestamps — must match exactly.
void _expectUnchanged({required Wish actual, required Wish reference}) {
  expect(actual.id, reference.id, reason: 'id');
  expect(actual.title, reference.title, reason: 'title');
  expect(actual.description, reference.description, reason: 'description');
  expect(actual.categoryId, reference.categoryId, reason: 'categoryId');
  expect(actual.priority, reference.priority, reason: 'priority');
  expect(actual.status, reference.status, reason: 'status');
  expect(actual.progress, reference.progress, reason: 'progress');
  expect(actual.createdAtUtc, _truncateToSeconds(reference.createdAtUtc),
      reason: 'createdAt unchanged (to the second)');
  expect(actual.updatedAtUtc, _truncateToSeconds(reference.updatedAtUtc),
      reason: 'updatedAt unchanged (to the second)');
}

/// Truncates [t] to whole seconds in UTC — the resolution the Drift
/// `dateTime()` column stores.
DateTime _truncateToSeconds(DateTime t) {
  final utc = t.toUtc();
  return DateTime.fromMillisecondsSinceEpoch(
    (utc.millisecondsSinceEpoch ~/ 1000) * 1000,
    isUtc: true,
  );
}

// --- Case specification + generators ----------------------------------------

/// The inputs for one Wish in the population.
class _WishSpec {
  const _WishSpec(this.title, this.description, this.priority);

  final String title;
  final String? description;
  final Priority priority;

  @override
  String toString() =>
      '_WishSpec(title: $title, description: $description, '
      'priority: ${priority.name})';
}

/// A non-empty population of Wish specs plus the index of the delete target.
class _DeleteCase {
  const _DeleteCase(this.specs, this.targetIndex);

  final List<_WishSpec> specs;
  final int targetIndex;

  @override
  String toString() =>
      '_DeleteCase(count: ${specs.length}, targetIndex: $targetIndex)';
}

/// Characters mixed into generated text to stress storage/escaping.
const String _specialChars = 'abcABC123 "\\/\n\r\t{}[],:😀é中🚀';

final Generator<String> _anyTitle = any.nonEmptyStringOf(_specialChars);

final Generator<String?> _anyDescription = any.oneOf<String?>([
  any.null_,
  any.always<String?>(''),
  any.stringOf(_specialChars).map<String?>((s) => s),
]);

final Generator<Priority> _anyPriority = any.choose(Priority.values);

final Generator<_WishSpec> _anyWishSpec = any.combine3(
  _anyTitle,
  _anyDescription,
  _anyPriority,
  (String title, String? description, Priority priority) =>
      _WishSpec(title, description, priority),
);

/// A non-empty population so there is always a target to delete. glados'
/// `nonEmptyList` guarantees at least one element.
final Generator<List<_WishSpec>> _anyPopulation =
    any.nonEmptyList(_anyWishSpec);

final Generator<_DeleteCase> _anyDeleteCase = _anyPopulation.bind(
  (List<_WishSpec> specs) => any.positiveIntOrZero.map(
    (int index) => _DeleteCase(specs, index),
  ),
);
