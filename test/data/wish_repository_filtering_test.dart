// Feature: wishable, Property 6: Filtering is sound and complete
//
// Property-based test for task 8.10.
//
// **Property 6: Filtering is sound and complete** (by Category, by
// Lifecycle_Status, and "all").
// **Validates: Requirements 3.4, 6.5, 9.1, 9.2, 9.3, 9.4**
//
// For any population of Wishes spread across several categories and lifecycle
// statuses, the repository's reactive filter streams must be both SOUND (every
// emitted Wish genuinely matches the filter) and COMPLETE (every matching Wish
// is emitted, none dropped):
//
//   - watchByStatus(s)   emits EXACTLY the Wishes whose status == s
//                        (R6.5, R9.2–R9.4).
//   - watchByCategory(c) emits EXACTLY the Wishes whose categoryId == c
//                        (R3.4).
//   - watchAll()         emits EXACTLY every stored Wish (R9.1).
//
// The population is built against a real Drift [AppDatabase] over an in-memory
// executor (`NativeDatabase.memory()`), so this exercises the actual SQL
// `where` clauses in [DriftWishRepository], not a stub. Each Wish is created
// through the repository and then driven to a random target lifecycle status
// via `transition`/`applyProgress`, so status values come from genuine
// lifecycle mutations rather than being written directly.
//
// A snapshot of each stream is taken with `stream.first`, which yields the
// current contents of the reactive query. The language and framework (Dart
// property testing via `glados`) follow the design's Testing Strategy.
library wishable.test.data.wish_repository_filtering_test;

import 'package:drift/native.dart';
import 'package:glados/glados.dart';
import 'package:wishable/data/app_database.dart';
import 'package:wishable/data/repositories/drift_category_repository.dart';
import 'package:wishable/data/repositories/drift_wish_repository.dart';
import 'package:wishable/domain/category.dart';
import 'package:wishable/domain/lifecycle_event.dart';
import 'package:wishable/domain/lifecycle_status.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';
import 'package:wishable/domain/wish_input.dart';

/// The names of the extra (non-preset) categories created for each case. Using
/// a small fixed pool keeps categories densely populated so the by-category
/// filter is exercised with multiple matches per category.
const List<String> _categoryNames = <String>[
  'Alpha',
  'Beta',
  'Gamma',
  'Delta',
];

/// A generated specification for a single Wish: which category (by index into
/// the created category pool) it belongs to and the target lifecycle status it
/// should be driven to after creation.
class _WishSpec {
  const _WishSpec(this.categoryIndex, this.targetStatus);

  final int categoryIndex;
  final LifecycleStatus targetStatus;

  @override
  String toString() => '_WishSpec(cat: $categoryIndex, '
      'status: ${targetStatus.name})';
}

/// Generators for the filtering property, registered on glados' [Any].
extension _FilteringAnys on Any {
  /// Any lifecycle status reachable through the repository's mutations.
  Generator<LifecycleStatus> get targetStatus => choose(LifecycleStatus.values);

  /// A single Wish specification. The category index is constrained to the
  /// created pool so every generated Wish references a real category.
  Generator<_WishSpec> get wishSpec => _combine2(
        intInRange(0, _categoryNames.length),
        targetStatus,
        (int index, LifecycleStatus status) => _WishSpec(index, status),
      );

  /// A population of Wish specifications.
  Generator<List<_WishSpec>> get wishSpecs => list(wishSpec);
}

/// Combines two generators into one producing a mapped value.
Generator<R> _combine2<A, B, R>(
  Generator<A> a,
  Generator<B> b,
  R Function(A, B) f,
) {
  return a.bind((A va) => b.map((B vb) => f(va, vb)));
}

void main() {
  Glados<List<_WishSpec>>(any.wishSpecs).test(
    'watchByStatus / watchByCategory / watchAll are each sound and complete',
    (List<_WishSpec> specs) async {
      final AppDatabase db = AppDatabase.forExecutor(NativeDatabase.memory());
      final DriftWishRepository wishes = DriftWishRepository(db);
      final DriftCategoryRepository categories = DriftCategoryRepository(db);

      try {
        // Create the category pool first (FK constraints are enforced, so a
        // Wish must reference an existing category).
        final List<Category> pool = <Category>[
          for (final String name in _categoryNames)
            await categories.getOrCreateByName(name),
        ];

        // Build the Wish population. We track the expected (id -> status) and
        // (id -> categoryId) independently of the repository so the assertions
        // compare against a model computed in the test, not re-derived from the
        // thing under test.
        final Map<String, LifecycleStatus> expectedStatus =
            <String, LifecycleStatus>{};
        final Map<String, String> expectedCategory = <String, String>{};

        for (int i = 0; i < specs.length; i++) {
          final _WishSpec spec = specs[i];
          final Category category = pool[spec.categoryIndex];

          final Wish created = await wishes.create(
            WishDraft(
              title: 'Wish $i',
              description: null,
              categoryId: category.id,
              priority: Priority.medium,
            ),
          );

          // Drive the Wish to its target status through genuine lifecycle
          // mutations. A freshly created Wish is Active with progress 0.
          final Wish driven =
              await _driveToStatus(wishes, created.id, spec.targetStatus);

          expectedStatus[driven.id] = driven.status;
          expectedCategory[driven.id] = category.id;
        }

        // --- watchAll(): completeness over the whole population -----------
        final List<Wish> all = await wishes.watchAll().first;
        expect(
          all.map((Wish w) => w.id).toSet(),
          equals(expectedStatus.keys.toSet()),
          reason: 'watchAll must emit exactly every stored Wish',
        );
        expect(
          all,
          hasLength(expectedStatus.length),
          reason: 'watchAll must not drop or duplicate Wishes',
        );

        // --- watchByStatus(s): sound + complete for every status ----------
        for (final LifecycleStatus status in LifecycleStatus.values) {
          final List<Wish> filtered = await wishes.watchByStatus(status).first;

          // Soundness: everything emitted really has this status.
          for (final Wish w in filtered) {
            expect(
              w.status,
              status,
              reason: 'watchByStatus($status) emitted a Wish with '
                  'status ${w.status}',
            );
          }

          // Completeness: the emitted id set equals the expected id set.
          final Set<String> emittedIds = filtered.map((Wish w) => w.id).toSet();
          final Set<String> expectedIds = expectedStatus.entries
              .where((MapEntry<String, LifecycleStatus> e) => e.value == status)
              .map((MapEntry<String, LifecycleStatus> e) => e.key)
              .toSet();
          expect(
            emittedIds,
            equals(expectedIds),
            reason: 'watchByStatus($status) is not sound+complete',
          );
          expect(
            filtered,
            hasLength(expectedIds.length),
            reason: 'watchByStatus($status) dropped or duplicated Wishes',
          );
        }

        // --- watchByCategory(c): sound + complete for every category ------
        for (final Category category in pool) {
          final List<Wish> filtered =
              await wishes.watchByCategory(category.id).first;

          // Soundness: everything emitted really belongs to this category.
          for (final Wish w in filtered) {
            expect(
              w.categoryId,
              category.id,
              reason: 'watchByCategory(${category.name}) emitted a Wish in '
                  'category ${w.categoryId}',
            );
          }

          // Completeness: the emitted id set equals the expected id set.
          final Set<String> emittedIds = filtered.map((Wish w) => w.id).toSet();
          final Set<String> expectedIds = expectedCategory.entries
              .where((MapEntry<String, String> e) => e.value == category.id)
              .map((MapEntry<String, String> e) => e.key)
              .toSet();
          expect(
            emittedIds,
            equals(expectedIds),
            reason: 'watchByCategory(${category.name}) is not sound+complete',
          );
          expect(
            filtered,
            hasLength(expectedIds.length),
            reason: 'watchByCategory(${category.name}) dropped or '
                'duplicated Wishes',
          );
        }
      } finally {
        await db.close();
      }
    },
  );
}

/// Drives the Wish identified by [id] from its freshly-created state (Active,
/// progress 0) to [target] using genuine repository lifecycle mutations, and
/// returns the resulting Wish.
///
///   - active     -> no mutation (creation state).
///   - inProgress -> raise progress to a mid value (0 -> >0 yields In_Progress).
///   - completed  -> Complete event (forces Completed, progress 100).
Future<Wish> _driveToStatus(
  DriftWishRepository repo,
  String id,
  LifecycleStatus target,
) async {
  switch (target) {
    case LifecycleStatus.active:
      final Wish? w = await repo.getById(id);
      return w!;
    case LifecycleStatus.inProgress:
      return repo.applyProgress(id, 42);
    case LifecycleStatus.completed:
      return repo.transition(id, const CompleteEvent());
  }
}
