// Feature: wishable, task 13.4 — Widget tests for the Wish detail view and its
// delete confirmation.
//
// Covers two contracts:
//
//   1. **Detail renders all fields (R9.5):** [WishDetailView] opened on a known
//      Wish shows every field of the record — title, description, the resolved
//      category NAME (not the raw id), the priority label, the status label,
//      the progress percentage, and the UTC created / last-updated timestamps.
//
//   2. **Delete is confirmation-gated (R8.2):** tapping the Delete action in
//      the AppBar does NOT remove the Wish; it first asks the controller for a
//      [DeleteRequest] and shows a "Delete Wish?" [AlertDialog] with Cancel /
//      Delete actions. Cancel is a pure no-op (R8.3-adjacent): the dialog is
//      dismissed and the repository's `delete()` is never called. Only tapping
//      Delete confirms the removal, at which point `delete()` IS called.
//
// No real Drift database is opened: the view reads its data through
// [allWishesProvider] (overridden to emit the known Wish) and through the
// interface-typed [wishRepositoryProvider] / [categoryRepositoryProvider],
// which are overridden with small recording fakes. The recording
// [_FakeWishRepository.deleteCalls] list is the single observable that proves
// exactly when — and whether — the delete write happens.
//
// Because a confirmed delete calls `context.goNamed(WishRoutes.allName)`, the
// view is hosted inside a minimal [GoRouter] whose `/all` route renders a
// placeholder, so navigation after confirmation resolves instead of crashing.
library wishable.test.presentation.wish_detail_view_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishable/application/application.dart';
import 'package:wishable/data/repositories/category_repository.dart';
import 'package:wishable/data/repositories/wish_repository.dart';
import 'package:wishable/domain/category.dart';
import 'package:wishable/domain/ids.dart';
import 'package:wishable/domain/lifecycle_event.dart';
import 'package:wishable/domain/lifecycle_status.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';
import 'package:wishable/domain/wish_input.dart';
import 'package:wishable/presentation/router/app_router.dart';
import 'package:wishable/presentation/views/wish_detail_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const WishId knownId = 'wish-known-id';
  const CategoryId knownCategoryId = 'cat-known-id';

  // A fixed, fully-populated Wish so every field has a concrete, assertable
  // value. Timestamps are UTC (R14.2) and distinct so created vs. updated can
  // be told apart on screen.
  final DateTime createdAt = DateTime.utc(2024, 1, 2, 3, 4, 5);
  final DateTime updatedAt = DateTime.utc(2024, 6, 7, 8, 9, 10);
  final Wish knownWish = Wish(
    id: knownId,
    title: 'Climb Mount Fuji',
    description: 'Reach the summit at sunrise.',
    categoryId: knownCategoryId,
    priority: Priority.high,
    status: LifecycleStatus.inProgress,
    progress: 40,
    createdAtUtc: createdAt,
    updatedAtUtc: updatedAt,
  );

  const Category knownCategory = Category(
    id: knownCategoryId,
    name: 'Travel',
    isPreset: true,
  );

  /// Builds a container whose data seams are all fakes/overrides so no Drift
  /// database is opened. Returns the recording wish-repository fake so tests
  /// can observe `delete()`.
  ({ProviderContainer container, _FakeWishRepository wishRepo})
      buildContainer() {
    final _FakeWishRepository wishRepo = _FakeWishRepository(<Wish>[knownWish]);
    final _FakeCategoryRepository categoryRepo =
        _FakeCategoryRepository(<Category>[knownCategory]);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        // The detail view resolves its Wish from this stream (R9.5).
        allWishesProvider.overrideWith(
          (Ref ref) => Stream<List<Wish>>.value(<Wish>[knownWish]),
        ),
        // requestDelete()/confirmDelete() route through this; it also records
        // delete() so the test can prove when the write happens.
        wishRepositoryProvider.overrideWithValue(wishRepo),
        // The category-name FutureProvider reads getAll() through this.
        categoryRepositoryProvider.overrideWithValue(categoryRepo),
      ],
    );
    return (container: container, wishRepo: wishRepo);
  }

  /// Pumps [WishDetailView] inside a minimal router so the post-confirm
  /// `goNamed(allName)` navigation resolves to a placeholder instead of
  /// crashing.
  Future<void> pumpDetail(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/detail',
      routes: <RouteBase>[
        GoRoute(
          path: '/detail',
          builder: (BuildContext context, GoRouterState state) =>
              const WishDetailView(wishId: knownId),
        ),
        GoRoute(
          path: WishRoutes.all,
          name: WishRoutes.allName,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('all-wishes-placeholder')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders every field of the Wish: title, description, category name, '
    'priority, status, progress, and UTC timestamps (R9.5)',
    (WidgetTester tester) async {
      final (:ProviderContainer container, :_FakeWishRepository wishRepo) =
          buildContainer();
      addTearDown(container.dispose);

      await pumpDetail(tester, container);

      // Title and description render verbatim.
      expect(find.text('Climb Mount Fuji'), findsOneWidget);
      expect(find.text('Reach the summit at sunrise.'), findsOneWidget);

      // Category shows the resolved NAME, not the raw id.
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text(knownCategoryId), findsNothing,
          reason: 'the category must resolve to its display name (R9.5)');

      // Priority and status labels (the view renders "Priority: High" and
      // "Status: In progress").
      expect(find.text('Priority: High'), findsOneWidget);
      expect(find.text('Status: In progress'), findsOneWidget);

      // Progress is shown as a percentage. The view renders the value in a
      // trailing label (e.g. "40%").
      expect(find.text('40%'), findsWidgets);

      // Both UTC timestamps are rendered as ISO-8601 "... (UTC)" strings.
      expect(
        find.text('${createdAt.toIso8601String()} (UTC)'),
        findsOneWidget,
        reason: 'the created timestamp must be shown in UTC (R9.5, R14.2)',
      );
      expect(
        find.text('${updatedAt.toIso8601String()} (UTC)'),
        findsOneWidget,
        reason: 'the last-updated timestamp must be shown in UTC (R9.5)',
      );
    },
  );

  testWidgets(
    'tapping Delete prompts a confirmation and does NOT delete; Cancel is a '
    'no-op that never writes (R8.2)',
    (WidgetTester tester) async {
      final (:ProviderContainer container, :_FakeWishRepository wishRepo) =
          buildContainer();
      addTearDown(container.dispose);

      await pumpDetail(tester, container);

      // Trigger the delete flow from the AppBar action.
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      // The confirmation dialog is shown with both actions, and NOTHING has
      // been deleted yet (R8.2).
      expect(find.text('Delete Wish?'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
      expect(wishRepo.deleteCalls, isEmpty,
          reason: 'showing the prompt must not delete anything (R8.2)');

      // Cancel abandons the deletion: dialog dismissed, still no write.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Wish?'), findsNothing,
          reason: 'cancelling dismisses the confirmation');
      expect(wishRepo.deleteCalls, isEmpty,
          reason: 'cancelling must perform no delete (R8.3)');
    },
  );

  testWidgets(
    'confirming the Delete prompt is what triggers the repository delete '
    '(R8.2, R8.1)',
    (WidgetTester tester) async {
      final (:ProviderContainer container, :_FakeWishRepository wishRepo) =
          buildContainer();
      addTearDown(container.dispose);

      await pumpDetail(tester, container);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      // Prompt is up and still nothing deleted.
      expect(find.text('Delete Wish?'), findsOneWidget);
      expect(wishRepo.deleteCalls, isEmpty,
          reason: 'the delete must not happen before confirmation (R8.2)');

      // Confirm the delete — only now may the write occur (R8.1).
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(wishRepo.deleteCalls, <WishId>[knownId],
          reason: 'confirming the prompt triggers the delete write (R8.1)');
      expect(find.text('Delete Wish?'), findsNothing,
          reason: 'the confirmation is dismissed on confirm');
    },
  );
}

/// A recording [WishRepository] fake over an in-memory list.
///
/// Only the methods the detail view and [WishActionController.requestDelete] /
/// `confirmDelete` touch are implemented: [getById] (to label the confirmation
/// prompt) and [delete] (the write under test, recorded in [deleteCalls]).
/// Reactive reads come from the overridden [allWishesProvider], so the stream
/// methods here are unused; the remaining members throw if exercised.
class _FakeWishRepository implements WishRepository {
  _FakeWishRepository(this._wishes);

  final List<Wish> _wishes;

  /// Ids passed to [delete], in call order. A delete occurred iff non-empty.
  final List<WishId> deleteCalls = <WishId>[];

  @override
  Future<Wish?> getById(WishId id) async {
    for (final Wish wish in _wishes) {
      if (wish.id == id) {
        return wish;
      }
    }
    return null;
  }

  @override
  Future<void> delete(WishId id) async {
    deleteCalls.add(id);
  }

  @override
  Future<Wish> create(WishDraft draft) =>
      throw UnimplementedError('create is not exercised by this test');

  @override
  Future<Wish> update(WishId id, WishEdit edit) =>
      throw UnimplementedError('update is not exercised by this test');

  @override
  Stream<List<Wish>> watchAll() =>
      throw UnimplementedError('watchAll is not exercised by this test');

  @override
  Stream<List<Wish>> watchByStatus(LifecycleStatus status) =>
      throw UnimplementedError('watchByStatus is not exercised by this test');

  @override
  Stream<List<Wish>> watchByCategory(CategoryId id) =>
      throw UnimplementedError('watchByCategory is not exercised by this test');

  @override
  Future<Wish> applyProgress(WishId id, int progress) =>
      throw UnimplementedError('applyProgress is not exercised by this test');

  @override
  Future<Wish> transition(WishId id, LifecycleEvent event) =>
      throw UnimplementedError('transition is not exercised by this test');

  @override
  Future<List<Wish>> getAll() =>
      throw UnimplementedError('getAll is not exercised by this test');

  @override
  Future<void> replaceAll(List<Wish> wishes) =>
      throw UnimplementedError('replaceAll is not exercised by this test');
}

/// A [CategoryRepository] fake whose [getAll] returns a fixed snapshot so the
/// detail view's id -> name lookup resolves (R9.5). The remaining members are
/// unused by this test.
class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository(this._categories);

  final List<Category> _categories;

  @override
  Future<List<Category>> getAll() async => _categories;

  @override
  Future<Category> getOrCreateByName(String name) => throw UnimplementedError(
        'getOrCreateByName is not exercised by this test',
      );

  @override
  Stream<List<Category>> watchAll() =>
      throw UnimplementedError('watchAll is not exercised by this test');
}
