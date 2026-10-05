// Feature: wishable, Property 10: Wish identifiers are unique and stable
//
// Property-based test for task 8.8.
//
// Property 10: Wish identifiers are unique and stable.
// Validates: Requirements 14.1.
//
// A Wish is assigned a stable UUID v4 identifier at creation that is unique
// across all Wishes and never changes for the life of the Wish (design R14.1).
// This test exercises the real [DriftWishRepository] over an in-memory
// [AppDatabase] (no mocks) and asserts both halves of the property:
//
//   - Uniqueness: creating N random [WishDraft]s yields N pairwise-distinct
//     ids.
//   - Stability: for a representative Wish, the id is preserved across every
//     mutation the repository exposes — update(), applyProgress(), and
//     transition() (Start / Complete / Reopen).
//
// A real [Category] row is created first via
// [DriftCategoryRepository.getOrCreateByName] so each draft's foreign key
// references an existing category. The language and framework (Dart property
// testing via `glados`) follow the design's Testing Strategy.

import 'package:drift/native.dart';
import 'package:glados/glados.dart';
import 'package:wishable/data/app_database.dart';
import 'package:wishable/data/repositories/drift_category_repository.dart';
import 'package:wishable/data/repositories/drift_wish_repository.dart';
import 'package:wishable/domain/category.dart';
import 'package:wishable/domain/lifecycle_event.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';
import 'package:wishable/domain/wish_input.dart';

/// Generators for the Wish-draft input space, registered on glados' [Any].
extension WishDraftAnys on Any {
  /// Any [Priority], or `null` so the repository's default-Medium path is also
  /// exercised. Priority has no bearing on identity but widens the input space.
  Generator<Priority?> get optionalPriority =>
      oneOf<Priority?>([always(null), ...Priority.values.map(always)]);

  /// A non-empty title. Repository `create` does not itself reject blank
  /// titles (validation lives in `WishValidator`), but a realistic generator
  /// keeps the data meaningful; we prefix a letter so the string is never
  /// empty regardless of the generated suffix.
  Generator<String> get wishTitle => letterOrDigits.map((String s) => 't$s');

  /// An optional description.
  Generator<String?> get optionalDescription =>
      oneOf<String?>([always(null), letterOrDigits]);

  /// A [WishDraft] with the given [categoryId]. categoryId is injected rather
  /// than generated because it must reference a category row that actually
  /// exists for the foreign key to hold.
  Generator<WishDraft> wishDraft(String categoryId) => combine4(
        wishTitle,
        optionalDescription,
        always(categoryId),
        optionalPriority,
        (String title, String? description, String id, Priority? priority) =>
            WishDraft(
          title: title,
          description: description,
          categoryId: id,
          priority: priority,
        ),
      );

  /// A list of 1..30 [WishDraft]s. At least one so the stability half always
  /// has a subject; capped so each generated case stays fast against the DB.
  Generator<List<WishDraft>> wishDrafts(String categoryId) =>
      listWithLengthInRange(1, 30, wishDraft(categoryId));
}

void main() {
  Glados<List<WishDraft>>(
    // The category id is only known at run time, so we build the draft
    // generator against a fixed sentinel id and rewrite categoryId inside the
    // test body once the real category exists. This keeps generation pure
    // while still referencing a valid FK.
    any.wishDrafts('__placeholder__'),
    // Explicitly ask for a generous number of generated cases so the property
    // is exercised across at least 100 random inputs.
    ExploreConfig(numRuns: 100),
  ).test(
    'ids are unique across created Wishes and stable across every mutation',
    (List<WishDraft> drafts) async {
      final AppDatabase db = AppDatabase.forExecutor(NativeDatabase.memory());
      try {
        final DriftCategoryRepository categories = DriftCategoryRepository(db);
        final DriftWishRepository wishes = DriftWishRepository(db);

        // Create the category first so each draft's foreign key resolves.
        final Category category =
            await categories.getOrCreateByName('Test Category');

        // Rebind every draft's categoryId to the real category id.
        final List<WishDraft> bound = drafts
            .map((WishDraft d) => d.copyWith(categoryId: category.id))
            .toList(growable: false);

        // --- Uniqueness --------------------------------------------------
        final List<Wish> created = <Wish>[];
        for (final WishDraft draft in bound) {
          created.add(await wishes.create(draft));
        }

        final List<String> ids =
            created.map((Wish w) => w.id).toList(growable: false);
        final Set<String> distinct = ids.toSet();
        expect(
          distinct.length,
          ids.length,
          reason: 'created ${ids.length} Wishes but only '
              '${distinct.length} distinct ids: not unique',
        );

        // Every id is also a non-empty string that persists under getById.
        for (final Wish w in created) {
          expect(w.id, isNotEmpty);
          final Wish? fetched = await wishes.getById(w.id);
          expect(fetched, isNotNull);
          expect(fetched!.id, w.id);
        }

        // --- Stability ---------------------------------------------------
        // Take the first created Wish as the mutation subject and assert its
        // id survives every repository mutation path.
        final Wish subject = created.first;
        final String originalId = subject.id;

        final Wish afterEdit = await wishes.update(
          originalId,
          WishEdit(
            title: 'edited-${subject.title}',
            description: 'edited description',
            categoryId: category.id,
            priority: Priority.high,
          ),
        );
        expect(afterEdit.id, originalId, reason: 'update() changed the id');

        final Wish afterProgress = await wishes.applyProgress(originalId, 42);
        expect(afterProgress.id, originalId,
            reason: 'applyProgress() changed the id');

        final Wish afterStart =
            await wishes.transition(originalId, const StartEvent());
        expect(afterStart.id, originalId,
            reason: 'transition(Start) changed the id');

        final Wish afterComplete =
            await wishes.transition(originalId, const CompleteEvent());
        expect(afterComplete.id, originalId,
            reason: 'transition(Complete) changed the id');

        final Wish afterReopen =
            await wishes.transition(originalId, const ReopenEvent());
        expect(afterReopen.id, originalId,
            reason: 'transition(Reopen) changed the id');

        // The persisted row still carries the original id after the mutations.
        final Wish? persisted = await wishes.getById(originalId);
        expect(persisted, isNotNull);
        expect(persisted!.id, originalId);

        // Mutating the subject did not clone or renumber the other Wishes:
        // the full set of ids is unchanged and still distinct.
        final List<Wish> all = await wishes.getAll();
        final Set<String> allIds = all.map((Wish w) => w.id).toSet();
        expect(allIds, equals(distinct),
            reason: 'mutations altered the set of Wish ids');
      } finally {
        await db.close();
      }
    },
  );
}
