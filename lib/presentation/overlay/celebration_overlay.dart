/// The Celebration View overlay (design "Celebration View"; R7.1–R7.3).
///
/// When a Wish transitions to `Completed`, the [CelebrationController] emits a
/// [CelebrationEvent]. This file turns that event into a MODAL overlay shown
/// above the current route: a dialog containing the message "Wish fulfilled"
/// and the completed Wish's title (R7.1, R7.3). Dismissing the dialog pops it
/// off the navigator, returning the User to whatever view was active before
/// the celebration appeared (R7.2) — nothing underneath is replaced, so the
/// originating route is restored automatically.
///
/// Two public widgets live here:
///
///   - [CelebrationListener] wraps the app's content (wired by task 16 via
///     `MaterialApp.builder`). It subscribes to
///     [CelebrationController.events] and shows the modal on each event.
///   - [CelebrationView] is the modal's content itself, exposed publicly so it
///     can be widget-tested directly (task 15.2) without driving the stream.
///
/// ## Layering discipline
///
/// Presentation layer only. Depends on the Application layer
/// ([celebrationControllerProvider]) and Flutter/Riverpod — never on Drift or
/// `dart:io` (design "Module boundaries").
library wishable.presentation.overlay.celebration_overlay;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/application.dart';
import '../../theme/app_theme.dart';

/// The message shown by the Celebration View (R7.1). Exposed so tests can
/// assert on the exact copy without duplicating the literal.
const String celebrationMessage = 'Wishlist fulfilled';

/// Wraps the app's content and presents the [CelebrationView] as a modal
/// overlay whenever the [CelebrationController] emits a [CelebrationEvent].
///
/// Place this around the router's child (task 16, e.g. via
/// `MaterialApp.builder`) so the dialog is pushed above the current route and
/// dismissing it returns to the originating view (R7.2).
///
/// It subscribes to [CelebrationController.events] in [initState] and shows a
/// modal dialog per event; the subscription is cancelled in [dispose]. The
/// stream (not `ref.listen`) is the source of truth because the controller
/// publishes celebrations on a broadcast [Stream].
class CelebrationListener extends ConsumerStatefulWidget {
  const CelebrationListener({required this.child, super.key});

  /// The app content shown beneath any celebration overlay.
  final Widget child;

  @override
  ConsumerState<CelebrationListener> createState() =>
      _CelebrationListenerState();
}

class _CelebrationListenerState extends ConsumerState<CelebrationListener> {
  StreamSubscription<CelebrationEvent>? _subscription;

  /// Guards against stacking a second celebration dialog if another event
  /// arrives while one is still on screen.
  bool _celebrationVisible = false;

  @override
  void initState() {
    super.initState();
    // Subscribe once to the broadcast stream of celebration events. Reading
    // (not watching) the provider is correct here: the controller is a stable
    // singleton and we drive one-shot UI from its stream.
    _subscription =
        ref.read(celebrationControllerProvider).events.listen(_onCelebration);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }

  /// Presents the modal Celebration View for [event] above the current route.
  Future<void> _onCelebration(CelebrationEvent event) async {
    if (!mounted || _celebrationVisible) {
      return;
    }
    _celebrationVisible = true;
    await showDialog<void>(
      context: context,
      // Modal: the barrier blocks interaction with the originating view until
      // the celebration is dismissed (R7.1).
      barrierDismissible: true,
      builder: (BuildContext context) => CelebrationView(
        title: event.title,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
    // The dialog has been popped — the originating route is now restored
    // (R7.2). Allow a subsequent celebration to show.
    _celebrationVisible = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The modal content of the Celebration View: a Material 3 dialog showing the
/// "Wish fulfilled" message and the completed Wish's [title] (R7.1, R7.3),
/// with a single action that dismisses it back to the originating view (R7.2).
///
/// Exposed publicly so it can be rendered and asserted on directly in a widget
/// test (task 15.2).
class CelebrationView extends StatelessWidget {
  const CelebrationView({
    required this.title,
    this.onDismiss,
    super.key,
  });

  /// The title of the completed Wish — the text identifying which Wish was
  /// fulfilled (R7.3).
  final String title;

  /// Invoked when the User dismisses the celebration. When presented by
  /// [CelebrationListener] this pops the dialog, returning to the originating
  /// view (R7.2). May be `null` in a standalone test harness.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(AppIcons.celebration, color: theme.colorScheme.primary),
      // R7.1: the celebration always carries the "Wish fulfilled" message.
      title: const Text(celebrationMessage),
      // R7.3: identify the completed Wish by its title.
      content: Text(
        title,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: onDismiss,
          child: const Text('Done'),
        ),
      ],
    );
  }
}
