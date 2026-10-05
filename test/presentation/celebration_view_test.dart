// Feature: wishable, task 15.2 — Widget test for celebration content and
// dismissal.
//
// **Proves: Requirements 7.1, 7.2, 7.3** — When a Wish transitions to
// `Completed`, a modal Celebration View appears above the current route
// showing "Wish fulfilled" (R7.1) and the completed Wish's title (R7.3), and
// dismissing it returns the User to the originating view (R7.2).
//
// Two scenarios:
//
//   1. Content (R7.1, R7.3): pump [CelebrationView] directly with a sample
//      title; assert it renders the exported [celebrationMessage] const
//      ("Wish fulfilled") AND the given title. Tap "Done" and assert the
//      onDismiss callback fired.
//
//   2. Overlay + dismissal (R7.1, R7.2): pump a small app whose home shows a
//      "Home" marker wrapped by [CelebrationListener] inside a Riverpod scope.
//      Fire a real celebration by reading [celebrationControllerProvider] from
//      the container and calling notifyTransition(activeWish, completedWish).
//      Assert the modal appears above the route ("Wish fulfilled" + title
//      visible, "Home" still beneath). Tap "Done", settle, and assert the
//      dialog is gone and the originating "Home" view is shown again (R7.2).
library wishable.test.presentation.celebration_view_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishable/application/application.dart';
import 'package:wishable/domain/domain.dart';
import 'package:wishable/presentation/overlay/celebration_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String sampleTitle = 'Run a marathon';

  // ---------------------------------------------------------------------------
  // Scenario 1 — the modal content renders the message + title and dismisses.
  // ---------------------------------------------------------------------------
  testWidgets(
    'CelebrationView renders "Wish fulfilled" and the title, and tapping Done '
    'invokes onDismiss (R7.1, R7.3)',
    (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelebrationView(
              title: sampleTitle,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // R7.1: the celebration carries the "Wish fulfilled" message. Assert via
      // the exported const so the test tracks the single source of truth.
      expect(find.text(celebrationMessage), findsOneWidget,
          reason: 'the celebration must show the "Wish fulfilled" message');
      expect(celebrationMessage, 'Wish fulfilled');

      // R7.3: the completed Wish's title identifies which Wish was fulfilled.
      expect(find.text(sampleTitle), findsOneWidget,
          reason: 'the celebration must show the completed Wish title');

      // Dismiss action is present and wired to onDismiss.
      expect(dismissed, isFalse, reason: 'not dismissed before any tap');
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pump();

      expect(dismissed, isTrue,
          reason: 'tapping Done must invoke the onDismiss callback');
    },
  );

  // ---------------------------------------------------------------------------
  // Scenario 2 — the overlay appears above the route and dismissal restores it.
  // ---------------------------------------------------------------------------
  testWidgets(
    'a celebration event shows the modal above the originating route; '
    'dismissing it restores that route (R7.1, R7.2)',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CelebrationListener(
              child: Scaffold(
                body: Center(child: Text('Home')),
              ),
            ),
          ),
        ),
      );

      // The originating view is shown and no celebration is up yet.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text(celebrationMessage), findsNothing,
          reason: 'no celebration before any completion event');

      // Fire a real celebration through the controller: an active Wish
      // transitions to completed. This emits exactly one CelebrationEvent.
      final DateTime now = DateTime.utc(2024);
      final Wish active = Wish(
        id: 'wish-1',
        title: sampleTitle,
        description: null,
        categoryId: 'cat-1',
        priority: Priority.medium,
        status: LifecycleStatus.active,
        progress: 40,
        createdAtUtc: now,
        updatedAtUtc: now,
      );
      final Wish completed = active.copyWith(
        status: LifecycleStatus.completed,
        progress: 100,
      );

      final CelebrationController controller =
          container.read(celebrationControllerProvider);
      final CelebrationEvent? event =
          controller.notifyTransition(active, completed);
      expect(event, isNotNull,
          reason: 'the →Completed edge must emit a celebration event');

      await tester.pumpAndSettle();

      // R7.1/R7.3: the modal appears with the message and the title.
      expect(find.text(celebrationMessage), findsOneWidget,
          reason: 'the celebration modal must appear above the route');
      expect(find.text(sampleTitle), findsOneWidget,
          reason: 'the modal must identify the completed Wish by title');

      // The originating route still exists beneath the modal barrier (R7.2:
      // nothing underneath is replaced).
      expect(find.text('Home'), findsOneWidget,
          reason: 'the originating view remains beneath the overlay');

      // Dismiss the celebration.
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      // R7.2: the dialog is gone and the originating view is shown again.
      expect(find.text(celebrationMessage), findsNothing,
          reason: 'dismissing the celebration pops the modal');
      expect(find.text('Home'), findsOneWidget,
          reason: 'dismissal returns the User to the originating view (R7.2)');
    },
  );
}
