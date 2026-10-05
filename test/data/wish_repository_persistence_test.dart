// Feature: wishable, Property 1: Persistence round-trip preserves all fields
//
// Property-based test for task 8.6.
//
// **Property 1: Persistence round-trip preserves all fields**
// **Validates: Requirements 1.1, 1.3, 2.1, 2.3, 3.1, 4.1, 9.5, 10.4**
//
// For any valid [WishDraft], persisting it through the Drift-backed
// [DriftWishRepository] and reading it back — both via [getById] (the detail
// view's single-record read, R9.5) and via [getAll] (the backup/export
// snapshot, R10.4) — yields a [Wish] whose every field matches what was
// stored:
//   - a newly created Wish is Active with progress 0 (R1.1),
//   - the title (R2.1), optional description incl. null/'' (R1.3, R2.3),
//     category FK (R3.1) and priority (R4.1) survive the round-trip,
//   - editing via [update] round-trips the edited fields and preserves the id.
//
// A separate durability test closes and reopens a *file* database over the
// same path to prove the data survives a process restart (R10.4) — the
// strongest form of "persistence round-trip".
//
// This test exercises real Drift I/O over an in-memory database
// (`NativeDatabase.memory()`), so it runs under `flutter_test`.
library wishable.test.data.wish_repository_persistence_test;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// glados supplies the property runner and its generator extensions on `Any`.
// Its `expect`/`test` clash with flutter_test's, so hide those two and let
// flutter_test provide `test`, `expect`, and the matchers.
import 'package:glados/glados.dart' hide expect, test;
import 'package:path/path.dart' as p;
import 'package:wishable/data/app_database.dart';
import 'package:wishable/data/repositories/drift_category_repository.dart';
import 'package:wishable/data/repositories/drift_wish_repository.dart';
import 'package:wishable/domain/category.dart';
import 'package:wishable/domain/lifecycle_status.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';
import 'package:wishable/domain/wish_input.dart';

void main() {
  // Required because the test touches the Flutter/Drift native bindings.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---- Property 1: in-memory round-trip ----------------------------------
  //
  // 100 generated cases (ExploreConfig.numRuns defaults to 100). Each case
  // runs against a fresh in-memory database so cases are fully isolated.
  Glados<_DraftSpec>(_anyDraftSpec, ExploreConfig(numRuns: 100)).test(
    'create() then getById()/getAll() preserves every field; '
    'update() round-trips edits and preserves the id',
    (spec) async {
      final AppDatabase db = AppDatabase.forExecutor(NativeDatabase.memory());
      try {
        final wishes = DriftWishRepository(db);
        final categories = DriftCategoryRepository(db);

        // A category must exist first to satisfy the FK (R3.1). Pick one of
        // the generated category names and resolve it idempotently.
        final Category category =
            await categories.getOrCreateByName(spec.categoryName);

        final WishDraft draft = WishDraft(
          title: spec.title,
          description: spec.description,
          categoryId: category.id,
          priority: spec.priority,
        );

        // --- create() ---------------------------------------------------
        final Wish created = await wishes.create(draft);

        // A new Wish is Active with progress 0 (R1.1).
        expect(created.status, LifecycleStatus.active);
        expect(created.progress, 0);
        // The draft fields survive (R1.3, R3.1, R4.1).
        expect(created.title, spec.title);
        expect(created.description, spec.description);
        expect(created.categoryId, category.id);
        expect(created.priority, spec.priority ?? Priority.medium);
        expect(created.id, isNotEmpty);
        // Timestamps are UTC (R1.5 / R10.4 durability metadata).
        expect(created.createdAtUtc.isUtc, isTrue);
        expect(created.updatedAtUtc.isUtc, isTrue);

        // --- getById() round-trip (detail view read, R9.5) --------------
        final Wish? byId = await wishes.getById(created.id);
        expect(byId, isNotNull);
        _expectRoundTrips(actual: byId!, reference: created);

        // --- getAll() round-trip (snapshot read, R10.4) -----------------
        final List<Wish> all = await wishes.getAll();
        expect(all, hasLength(1));
        _expectRoundTrips(actual: all.single, reference: created);

        // Both reads come straight from the database, so they must agree
        // exactly on every field (same stored resolution).
        expect(all.single, equals(byId));

        // --- update() round-trips edits and preserves the id (R2.1/2.3) -
        final Category editedCategory =
            await categories.getOrCreateByName(spec.editedCategoryName);
        final WishEdit edit = WishEdit(
          title: spec.editedTitle,
          description: spec.editedDescription,
          categoryId: editedCategory.id,
          priority: spec.editedPriority,
        );
        final Wish updated = await wishes.update(created.id, edit);

        expect(updated.id, created.id, reason: 'id must be preserved on edit');
        expect(updated.title, spec.editedTitle);
        expect(updated.description, spec.editedDescription);
        expect(updated.categoryId, editedCategory.id);
        expect(updated.priority, spec.editedPriority);
        // Lifecycle state is untouched by a bare edit.
        expect(updated.status, created.status);
        expect(updated.progress, created.progress);
        // createdAt is immutable across an edit; update() reloads the stored
        // (second-resolution) row, so it equals the created instant truncated
        // to the second. updatedAt stays UTC.
        expect(updated.createdAtUtc, _truncateToSeconds(created.createdAtUtc));
        expect(updated.updatedAtUtc.isUtc, isTrue);

        // The edit is durable: re-read reflects exactly the edited record.
        final Wish? afterEdit = await wishes.getById(created.id);
        expect(afterEdit, isNotNull);
        _expectRoundTrips(actual: afterEdit!, reference: updated);
      } finally {
        await db.close();
      }
    },
  );

  // ---- Durability: close/reopen a FILE database --------------------------
  //
  // The strongest round-trip: write wishes to an on-disk SQLite file, close
  // the database (flushing to disk), then open a brand-new AppDatabase over
  // the same file and assert the wishes survived unchanged (R10.4).
  test('wishes survive a close/reopen cycle on a file-backed database',
      () async {
    final Directory tempDir =
        await Directory.systemTemp.createTemp('wishable_persist_');
    final File dbFile = File(p.join(tempDir.path, 'wishable_test.sqlite'));

    // A deterministic batch of random drafts covering the input space.
    final List<_DraftSpec> specs = _sampleDraftSpecs(count: 25, seed: 1234);

    List<Wish> written;
    try {
      // --- Session 1: write ------------------------------------------------
      final AppDatabase db1 = AppDatabase.forExecutor(NativeDatabase(dbFile));
      try {
        final wishes = DriftWishRepository(db1);
        final categories = DriftCategoryRepository(db1);

        final List<Wish> created = <Wish>[];
        for (final spec in specs) {
          final Category category =
              await categories.getOrCreateByName(spec.categoryName);
          created.add(await wishes.create(WishDraft(
            title: spec.title,
            description: spec.description,
            categoryId: category.id,
            priority: spec.priority,
          )));
        }
        written = created;
      } finally {
        // Close flushes everything to the file and releases the handle.
        await db1.close();
      }

      // --- Session 2: reopen and verify -----------------------------------
      final AppDatabase db2 = AppDatabase.forExecutor(NativeDatabase(dbFile));
      try {
        final wishes = DriftWishRepository(db2);
        final List<Wish> reloaded = await wishes.getAll();

        // Same count, and every written Wish is present field-for-field
        // (order-independent).
        expect(reloaded, hasLength(written.length));
        final Map<String, Wish> byId = <String, Wish>{
          for (final w in reloaded) w.id: w,
        };
        for (final original in written) {
          final Wish? survivor = byId[original.id];
          expect(survivor, isNotNull,
              reason: 'Wish ${original.id} must survive the reopen');
          _expectRoundTrips(actual: survivor!, reference: original);
        }
      } finally {
        await db2.close();
      }
    } finally {
      // Clean up the temp database file and directory.
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}

// --- Round-trip assertion ---------------------------------------------------

/// Asserts that [actual] (a value read back from the database) round-trips the
/// [reference] (the value returned by the mutating call) on every domain field.
///
/// Every field is compared exactly EXCEPT the two timestamps: Drift's
/// `dateTime()` column stores an instant as whole Unix seconds, so persistence
/// preserves timestamps at second resolution and truncates any sub-second
/// component. The round-trip guarantee is therefore "same instant to the
/// second", which this helper checks by truncating the reference to seconds.
/// The stored timestamps must remain in UTC (R14.2).
void _expectRoundTrips({required Wish actual, required Wish reference}) {
  expect(actual.id, reference.id, reason: 'id');
  expect(actual.title, reference.title, reason: 'title');
  expect(actual.description, reference.description, reason: 'description');
  expect(actual.categoryId, reference.categoryId, reason: 'categoryId');
  expect(actual.priority, reference.priority, reason: 'priority');
  expect(actual.status, reference.status, reason: 'status');
  expect(actual.progress, reference.progress, reason: 'progress');

  expect(actual.createdAtUtc.isUtc, isTrue, reason: 'createdAt stays UTC');
  expect(actual.updatedAtUtc.isUtc, isTrue, reason: 'updatedAt stays UTC');
  expect(actual.createdAtUtc, _truncateToSeconds(reference.createdAtUtc),
      reason: 'createdAt round-trips to the second');
  expect(actual.updatedAtUtc, _truncateToSeconds(reference.updatedAtUtc),
      reason: 'updatedAt round-trips to the second');
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

// --- Draft specification + generators ---------------------------------------

/// A fully-specified set of inputs for one round-trip case: the fields for the
/// initial [WishDraft] plus the fields for a follow-up [WishEdit].
class _DraftSpec {
  const _DraftSpec({
    required this.title,
    required this.description,
    required this.categoryName,
    required this.priority,
    required this.editedTitle,
    required this.editedDescription,
    required this.editedCategoryName,
    required this.editedPriority,
  });

  final String title;
  final String? description;
  final String categoryName;
  final Priority? priority;

  final String editedTitle;
  final String? editedDescription;
  final String editedCategoryName;
  final Priority editedPriority;

  @override
  String toString() => '_DraftSpec(title: $title, description: $description, '
      'categoryName: $categoryName, priority: $priority -> '
      'editedTitle: $editedTitle, editedDescription: $editedDescription, '
      'editedCategoryName: $editedCategoryName, '
      'editedPriority: $editedPriority)';
}

/// Characters mixed into generated text to stress storage/escaping: ASCII
/// letters and digits plus Unicode/special code points.
const String _specialChars = 'abcABC123 "\\/\n\r\t{}[],:😀é中🚀';

/// A non-empty title drawn from [_specialChars] (R1.2 requires non-empty).
final Generator<String> _anyNonEmptyText = any.nonEmptyStringOf(_specialChars);

/// A non-empty category name (categories are stored by their unique name).
final Generator<String> _anyCategoryName = _anyNonEmptyText;

/// An optional description: `null`, the empty string, or arbitrary text
/// including Unicode/special characters (R1.3, R2.3).
final Generator<String?> _anyOptionalText = any.oneOf<String?>([
  any.null_,
  any.always<String?>(''),
  any.stringOf(_specialChars).map<String?>((s) => s),
]);

/// A random priority, or `null` to exercise the Medium default (R1.4) on
/// create. Edits always carry an explicit priority (R4.1).
final Generator<Priority?> _anyOptionalPriority = any.oneOf<Priority?>([
  any.null_,
  any.choose(Priority.values).map<Priority?>((p) => p),
]);

/// Generates a full [_DraftSpec] exercising the whole persisted input space.
final Generator<_DraftSpec> _anyDraftSpec = any.combine8(
  _anyNonEmptyText, // title
  _anyOptionalText, // description
  _anyCategoryName, // categoryName
  _anyOptionalPriority, // priority (incl. null -> Medium default)
  _anyNonEmptyText, // editedTitle
  _anyOptionalText, // editedDescription
  _anyCategoryName, // editedCategoryName
  any.choose(Priority.values), // editedPriority (always explicit)
  (
    String title,
    String? description,
    String categoryName,
    Priority? priority,
    String editedTitle,
    String? editedDescription,
    String editedCategoryName,
    Priority editedPriority,
  ) =>
      _DraftSpec(
    title: title,
    description: description,
    categoryName: categoryName,
    priority: priority,
    editedTitle: editedTitle,
    editedDescription: editedDescription,
    editedCategoryName: editedCategoryName,
    editedPriority: editedPriority,
  ),
);

/// Draws [count] deterministic [_DraftSpec]s from the generator using a seeded
/// [Random], for the file-based durability test (which is a single `test`, not
/// a Glados property, but still wants varied inputs).
List<_DraftSpec> _sampleDraftSpecs({required int count, required int seed}) {
  final random = Random(seed);
  return List<_DraftSpec>.generate(
    count,
    (i) => _anyDraftSpec(random, 10 + i).value,
    growable: false,
  );
}
