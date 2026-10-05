// Feature: wishable, Property 12: Cancelled delete is a no-op
//
// Property-based test for task 11.8.
//
// **Property 12: Cancelled delete is a no-op**
// **Validates: Requirements 8.3**
//
// For any population of persisted Wishes, asking to delete a target Wish and
// then CANCELLING must leave the Local_Database COMPLETELY UNCHANGED — the same
// Wishes, each with the same fields, and the same count — so the Wish is
// retained (R8.3):
//
//   - `requestDelete(id)` begins a confirmation-gated deletion and performs no
//     repository mutation (R8.2); it just names the pending request, then
//   - `cancelDelete(request)` is a pure no-op — it issues no repository call
//     and changes no state (R8.3).
//
// The test snapshots `getAll()` before the request/cancel pair and again after,
// and asserts the two snapshots are equal field-for-field (same id set, same
// count, every field identical). As a contrast — to show cancel is distinct
// from confirm — it then confirms the delete and asserts the target IS removed,
// proving the earlier no-op was genuinely retaining the Wish rather than the
// database being immutable.
//
// The controller runs over a REAL in-memory Drift [AppDatabase] wired through a
// Riverpod [ProviderContainer]: `appDatabaseProvider` is overridden to an
// in-memory `AppDatabase.forExecutor(NativeDatabase.memory())`, and the
// controller/repository are read back from the container, so this exercises the
// actual repository and SQL — not a stub. A single category is created first to
// satisfy the Wishes FK (R3.1), and every Wish is created through the
// repository.
//
// The language and framework (Dart property testing via `glados`) follow the
// design's Testing Strategy. glados' `expect`/`test` clash with flutter_test's,
// so those two are hidden and flutter_test provides the runner and matchers.
library wishable.test.application.wish_action_cancel_delete_test;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, test;
import 'package:riverpod/riverpod.dart';
import 'package:wishable/application/controllers/wish_action_controller.dart';
import 'package:wishable/application/providers.dart';
import 'package:wishable/data/app_database.dart';
import 'package:wishable/data/repositories/wish_repository.dart';
import 'package:wishable/domain/category.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';
import 'package:wishable/domain/wish_input.dart';

void main() {
  // Required because the test touches the Flutter/Drift native bindings.
  TestWidgetsFlutterBinding.ensureInitialized();

  // 100 generated cases. Each generates a non-empty population plus an index
  // selecting the cancel target, run against a fresh in-memory database wired
  // through its own ProviderContainer so the cases stay fully isolated.
  Glados<_CancelCase>(_anyCancelCase, ExploreConfig(numRuns: 100)).test(
    'requestDelete followed by cancelDelete leaves the database completely '
    'unchanged (no-op); confirmDelete still removes the target',
    (_CancelCase testCase) async {
      final AppDatabase db = AppDatabase.forExecutor(NativeDatabase.memory());
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      try {
        final WishActionController controller =
            container.read(wishActionControllerProvider);
        final WishRepository wishes = container.read(wishRepositoryProvider);
        final categories = container.read(categoryRepositoryProvider);

        // A single category satisfies the Wishes FK (R3.1).
        final Category category =
            await categories.getOrCreateByName('CancelCategory');

        // Build the population through the repository.
        final List<Wish> created = <Wish>[];
        for (final _WishSpec spec in testCase.specs) {
          created.add(await wishes.create(WishDraft(
            title: spec.title,
            description: spec.description,
            categoryId: category.id,
            priority: spec.priority,
          )));
        }

        // Pick the target deterministically from the generated index.
        final Wish target = created[testCase.targetIndex % created.length];

        // --- snapshot BEFORE the request/cancel pair -------------------
        final Map<String, Wish> before = <String, Wish>{
          for (final Wish w in await wishes.getAll()) w.id: w,
        };

        // --- the operation under test: request then CANCEL -------------
        final DeleteRequest? request = await controller.requestDelete(target.id);
        expect(request, isNotNull,
            reason: 'requestDelete must return a request for an existing Wish');
        expect(request!.id, target.id,
            reason: 'the request must name the target Wish');

        // The user cancels — this must be a pure no-op (R8.3).
        controller.cancelDelete(request);

        // --- snapshot AFTER: must be identical to BEFORE ---------------
        final Map<String, Wish> after = <String, Wish>{
          for (final Wish w in await wishes.getAll()) w.id: w,
        };

        expect(after.keys.toSet(), equals(before.keys.toSet()),
            reason: 'cancel must leave exactly the same set of Wishes (R8.3)');
        expect(after, hasLength(before.length),
            reason: 'cancel must not change the Wish count (R8.3)');
        expect(after, contains(target.id),
            reason: 'the cancelled Wish must be retained (R8.3)');

        for (final String id in before.keys) {
          _expectUnchanged(actual: after[id]!, reference: before[id]!);
        }

        // --- contrast: confirmDelete DOES remove the target -----------
        // Proves the earlier no-op retained the Wish rather than the database
        // simply being unable to change.
        await controller.confirmDelete(request);
        final Wish? deleted = await wishes.getById(target.id);
        expect(deleted, isNull,
            reason: 'confirmDelete must remove the target (R8.1), '
                'showing cancel is distinct from confirm');
        final Set<String> remainingIds =
            (await wishes.getAll()).map((Wish w) => w.id).toSet();
        expect(remainingIds, equals(before.keys.toSet()..remove(target.id)),
            reason: 'confirmDelete removes exactly the target and nothing else');
      } finally {
        container.dispose();
        await db.close();
      }
    },
  );
}

// --- Unchanged assertion ----------------------------------------------------

/// Asserts a Wish is field-for-field the record it was before the cancelled
/// delete. `getAll()` is read both before and after, so every field — including
/// the timestamps — must match exactly for a genuine no-op.
void _expectUnchanged({required Wish actual, required Wish reference}) {
  expect(actual.id, reference.id, reason: 'id');
  expect(actual.title, reference.title, reason: 'title');
  expect(actual.description, reference.description, reason: 'description');
  expect(actual.categoryId, reference.categoryId, reason: 'categoryId');
  expect(actual.priority, reference.priority, reason: 'priority');
  expect(actual.status, reference.status, reason: 'status');
  expect(actual.progress, reference.progress, reason: 'progress');
  expect(actual.createdAtUtc, reference.createdAtUtc, reason: 'createdAt');
  expect(actual.updatedAtUtc, reference.updatedAtUtc, reason: 'updatedAt');
}

// --- Case specification + generators ----------------------------------------

/// The inputs for one Wish in the population.
class _WishSpec {
  const _WishSpec(this.title, this.description, this.priority);

  final String title;
  final String? description;
  final Priority priority;

  @override
  String toString() => '_WishSpec(title: $title, description: $description, '
      'priority: ${priority.name})';
}

/// A non-empty population of Wish specs plus the index of the cancel target.
class _CancelCase {
  const _CancelCase(this.specs, this.targetIndex);

  final List<_WishSpec> specs;
  final int targetIndex;

  @override
  String toString() =>
      '_CancelCase(count: ${specs.length}, targetIndex: $targetIndex)';
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

/// A non-empty population so there is always a target to cancel. glados'
/// `nonEmptyList` guarantees at least one element.
final Generator<List<_WishSpec>> _anyPopulation =
    any.nonEmptyList(_anyWishSpec);

final Generator<_CancelCase> _anyCancelCase = _anyPopulation.bind(
  (List<_WishSpec> specs) => any.positiveIntOrZero.map(
    (int index) => _CancelCase(specs, index),
  ),
);
