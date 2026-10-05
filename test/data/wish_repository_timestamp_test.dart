// Feature: wishable, Property 4: Timestamps are recorded in UTC with correct ordering
//
// Property-based test for task 8.7.
//
// Property 4: Timestamps are recorded in UTC with correct ordering.
// Validates: Requirements 1.5, 2.4, 14.2.
//
// This test exercises the Drift-backed [DriftWishRepository] over an in-memory
// [AppDatabase] (NativeDatabase.memory()). For each randomly generated
// [WishDraft] it asserts the two halves of the property:
//
//   - On create (R1.5, R14.2): both timestamps are in UTC and the created and
//     updated instants are identical (a brand-new Wish has never been
//     modified, so createdAtUtc == updatedAtUtc).
//   - On a subsequent update()/applyProgress() (R2.4, R14.2): updatedAtUtc is
//     still in UTC and never precedes the creation instant — the ordering
//     invariant updatedAtUtc >= createdAtUtc holds, while createdAtUtc itself
//     is left untouched.
//
// A category is created up front via DriftCategoryRepository.getOrCreateByName
// so the generated drafts satisfy the Wishes -> Categories foreign key. The
// framework (Dart property testing via `glados`) follows the design's Testing
// Strategy; the repository under test is real (no mocks) and runs entirely in
// memory. glados' default ExploreConfig.numRuns is 100, so the property runs
// over at least 100 generated cases.

import 'package:drift/native.dart';
import 'package:glados/glados.dart';
import 'package:wishable/data/app_database.dart';
import 'package:wishable/data/repositories/drift_category_repository.dart';
import 'package:wishable/data/repositories/drift_wish_repository.dart';
import 'package:wishable/domain/category.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';
import 'package:wishable/domain/wish_input.dart';

/// Generates strings usable as Wish titles. The repository does not validate
/// titles (that is `WishValidator`'s job), but a guaranteed non-whitespace
/// character keeps generated drafts realistic.
Generator<String> titles() => any.letterOrDigits.map((String s) => 'w$s');

/// Generates optional descriptions: sometimes null, sometimes arbitrary text,
/// to exercise the full draft shape.
Generator<String?> optionalDescriptions() => any.either<String?>(
      any.always<String?>(null),
      any.letterOrDigits.map<String?>((String s) => s),
    );

/// Generates any member of the closed [Priority] set, plus `null` to exercise
/// the default-priority path on create.
Generator<Priority?> optionalPriorities() => any.choose<Priority?>(
      <Priority?>[null, ...Priority.values],
    );

/// Truncates [t] to whole-second resolution. The timestamp columns persist at
/// second precision, so a value just read back from storage loses the
/// sub-second component of the in-memory instant it was written from.
/// Comparing at this resolution asserts the creation instant is preserved
/// without conflating that with the storage layer's precision.
DateTime _toSeconds(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
      (t.millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );

void main() {
  group('Property 4: Timestamps are recorded in UTC with correct ordering', () {
    Glados3<String, String?, Priority?>(
      titles(),
      optionalDescriptions(),
      optionalPriorities(),
    ).test(
      'create records UTC timestamps and update preserves UTC ordering',
      (String title, String? description, Priority? priority) async {
        final AppDatabase db = AppDatabase.forExecutor(NativeDatabase.memory());
        try {
          final DriftWishRepository wishes = DriftWishRepository(db);
          final DriftCategoryRepository categories =
              DriftCategoryRepository(db);

          // Create a category so the Wish's foreign key resolves.
          final Category category =
              await categories.getOrCreateByName('Property4-Category');

          final WishDraft draft = WishDraft(
            title: title,
            description: description,
            categoryId: category.id,
            priority: priority,
          );

          // --- Create: both timestamps are UTC and identical (R1.5, R14.2).
          final Wish created = await wishes.create(draft);
          expect(created.createdAtUtc.isUtc, isTrue,
              reason: 'createdAtUtc must be recorded in UTC (R1.5, R14.2).');
          expect(created.updatedAtUtc.isUtc, isTrue,
              reason: 'updatedAtUtc must be recorded in UTC (R1.5, R14.2).');
          expect(created.updatedAtUtc, created.createdAtUtc,
              reason: 'A newly created Wish is unmodified, so createdAtUtc == '
                  'updatedAtUtc (R1.5).');

          // --- Update: updatedAtUtc stays UTC and never precedes creation.
          final Wish edited = await wishes.update(
            created.id,
            WishEdit(
              title: '${created.title}-edited',
              description: created.description,
              categoryId: created.categoryId,
              priority: created.priority,
            ),
          );
          expect(edited.updatedAtUtc.isUtc, isTrue,
              reason: 'updatedAtUtc must stay in UTC after update (R2.4).');
          // The creation instant is preserved (compared at the storage layer's
          // whole-second resolution, since the value was read back from the DB).
          expect(
              _toSeconds(edited.createdAtUtc), _toSeconds(created.createdAtUtc),
              reason: 'update() must not change the creation instant.');
          expect(
            edited.updatedAtUtc.isAfter(edited.createdAtUtc) ||
                edited.updatedAtUtc == edited.createdAtUtc,
            isTrue,
            reason: 'Ordering invariant: updatedAtUtc >= createdAtUtc (R2.4).',
          );

          // --- applyProgress: lifecycle mutation also refreshes updatedAtUtc
          //     in UTC while keeping the ordering invariant.
          final Wish progressed = await wishes.applyProgress(created.id, 50);
          expect(progressed.updatedAtUtc.isUtc, isTrue,
              reason:
                  'updatedAtUtc must stay in UTC after applyProgress (R2.4).');
          expect(_toSeconds(progressed.createdAtUtc),
              _toSeconds(created.createdAtUtc),
              reason: 'applyProgress must not change the creation instant.');
          expect(
            progressed.updatedAtUtc.isAfter(progressed.createdAtUtc) ||
                progressed.updatedAtUtc == progressed.createdAtUtc,
            isTrue,
            reason: 'Ordering invariant: updatedAtUtc >= createdAtUtc (R2.4).',
          );
        } finally {
          await db.close();
        }
      },
    );
  });
}
