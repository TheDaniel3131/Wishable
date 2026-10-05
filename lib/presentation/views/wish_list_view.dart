/// Lifecycle list views (task 13.1) — the four browsing screens that back the
/// shell's lifecycle tabs plus the "all" tab (R9.1–R9.4), with tap-to-open
/// handoff to the Wish detail route (R9.5).
///
/// ## Shape
///
/// [WishListView] is a reusable [ConsumerWidget] parameterized by a
/// `StreamProvider<List<Wish>>` and a human [title]. It `watch`es the provider
/// and renders the resulting `AsyncValue<List<Wish>>` across its three states:
///
///   - loading  — a centered [CircularProgressIndicator];
///   - error    — a friendly, retry-less error panel (the stream self-heals
///                when the database recovers);
///   - data     — a [ListView] of Wishes (High -> Low priority, already sorted
///                by [WishListController]) showing each Wish's title, priority,
///                lifecycle status, and progress; an empty list shows a
///                friendly empty-state message.
///
/// Tapping a row navigates to that Wish's detail route via
/// `context.goNamed(WishRoutes.detailName, pathParameters: {'id': wish.id})`
/// (R9.5), keeping the user within the current lifecycle branch.
///
/// The four concrete views ([AllWishesView], [ActiveWishesView],
/// [InProgressWishesView], [CompletedWishesView]) are thin wrappers that bind
/// [WishListView] to the matching provider from the wish-list controllers
/// (R9.1–R9.4). The router (task 12.1) returns these directly from its branch
/// builders.
///
/// ## Layering (design "Module boundaries")
///
/// Presentation-layer only. It depends on the application layer (the
/// `*WishesProvider`s) and the Drift-free domain models ([Wish], [Priority],
/// [LifecycleStatus]); it never imports Drift or `dart:io`.
library wishable.presentation.views.wish_list_view;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/application.dart';
import '../../domain/domain.dart';
import '../../theme/app_theme.dart';
import '../brand/wishable_logo.dart';
import '../router/app_router.dart';

/// A reusable lifecycle list screen bound to a [provider] yielding a
/// priority-sorted `List<Wish>`.
///
/// Renders loading / error / empty / data states and opens the detail route
/// on tap (R9.5). The four lifecycle tabs are built from this widget via the
/// wrappers below.
class WishListView extends ConsumerWidget {
  const WishListView({
    required this.title,
    required this.provider,
    required this.emptyMessage,
    super.key,
  });

  /// Title shown in the [AppBar].
  final String title;

  /// The wish-list controller stream this view renders (R9.1–R9.4).
  final ProviderListenable<AsyncValue<List<Wish>>> provider;

  /// Friendly message shown when the list is empty.
  final String emptyMessage;

  /// Shows a confirmation dialog before a swipe-to-delete removes [wish]
  /// (R8.2). Returns true only when the user confirms.
  Future<bool> _confirmDelete(BuildContext context, Wish wish) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Wish?'),
        content: Text('Delete "${wish.title}"? This cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Wish>> wishes = ref.watch(provider);
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: wishes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            _ErrorState(message: error.toString()),
        data: (List<Wish> list) {
          if (list.isEmpty) {
            return _EmptyState(message: emptyMessage);
          }
          return ListView.builder(
            // Bottom padding leaves room so the FAB never covers the last row.
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final Wish wish = list[index];
              return Dismissible(
                key: ValueKey<String>(wish.id),
                direction: DismissDirection.endToStart,
                // Confirm before removing so a stray swipe never deletes (R8.2).
                confirmDismiss: (_) => _confirmDelete(context, wish),
                onDismissed: (_) {
                  final WishActionController controller =
                      ref.read(wishActionControllerProvider);
                  controller.confirmDelete(
                      DeleteRequest(id: wish.id, title: wish.title));
                },
                background: const _DeleteSwipeBackground(),
                child: _WishListTile(wish: wish),
              );
            },
          );
        },
      ),
      // Primary action: create a new Wish (R1). Every lifecycle list screen
      // exposes it so the "Tap + to add" empty-state hint is always actionable.
      // Enlarged for a prominent, premium primary action.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.goNamed(WishRoutes.newWishName),
        icon: const Icon(Icons.add, size: 28),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Text(
            'New Wish',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
        tooltip: 'Create a new Wish',
      ),
    );
  }
}

/// A single row in a [WishListView]. Shows the Wish's title, priority, status,
/// and progress, opens the detail route when tapped (R9.5), and exposes an
/// explicit Edit/Delete overflow menu (so delete is reachable without swiping,
/// which is not discoverable with a mouse on web/desktop).
class _WishListTile extends ConsumerWidget {
  const _WishListTile({required this.wish});

  final Wish wish;

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Wish?'),
        content: Text('Delete "${wish.title}"? This cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref
          .read(wishActionControllerProvider)
          .confirmDelete(DeleteRequest(id: wish.id, title: wish.title));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final double fraction = (wish.progress.clamp(0, 100)) / 100;
    return ListTile(
      leading: Icon(_statusIcon(wish.status)),
      title: Text(
        wish.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              _MetaChip(
                icon: _priorityIcon(wish.priority),
                label: _priorityLabel(wish.priority),
              ),
              const SizedBox(width: 8),
              _MetaChip(
                icon: _statusIcon(wish.status),
                label: _statusLabel(wish.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${wish.progress}%',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        tooltip: 'Actions',
        icon: const Icon(Icons.more_vert),
        onSelected: (String action) {
          switch (action) {
            case 'edit':
              context.goNamed(
                WishRoutes.editName,
                pathParameters: <String, String>{'id': wish.id},
              );
            case 'delete':
              _confirmAndDelete(context, ref);
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: ListTile(
              leading:
                  Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text('Delete',
                  style: TextStyle(color: theme.colorScheme.error)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      onTap: () => context.goNamed(
        WishRoutes.detailName,
        pathParameters: <String, String>{'id': wish.id},
      ),
    );
  }

  /// Material Symbols glyph for a lifecycle [status].
  static IconData _statusIcon(LifecycleStatus status) => switch (status) {
        LifecycleStatus.active => AppIcons.active,
        LifecycleStatus.inProgress => AppIcons.inProgress,
        LifecycleStatus.completed => AppIcons.completed,
      };

  /// Human-readable label for a lifecycle [status].
  static String _statusLabel(LifecycleStatus status) => switch (status) {
        LifecycleStatus.active => 'Active',
        LifecycleStatus.inProgress => 'In progress',
        LifecycleStatus.completed => 'Completed',
      };

  /// Icon representing a [priority] ranking.
  static IconData _priorityIcon(Priority priority) => switch (priority) {
        Priority.high => Icons.keyboard_double_arrow_up,
        Priority.medium => Icons.drag_handle,
        Priority.low => Icons.keyboard_double_arrow_down,
      };

  /// Human-readable label for a [priority] ranking.
  static String _priorityLabel(Priority priority) => switch (priority) {
        Priority.high => 'High',
        Priority.medium => 'Medium',
        Priority.low => 'Low',
      };
}

/// A compact icon + label pill used to show a Wish's priority and status in a
/// list row.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Red "delete" background revealed when swiping a list row from right to left.
class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Text(
            'Delete',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}

/// Friendly empty-state shown when a lifecycle list has no Wishes.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Opacity(opacity: 0.9, child: WishableLogo(size: 72)),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error panel shown when a wish-list stream emits an error.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong loading your Wishes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// All Wishes regardless of lifecycle status (R9.1).
class AllWishesView extends StatelessWidget {
  const AllWishesView({super.key});

  @override
  Widget build(BuildContext context) {
    return WishListView(
      title: 'All Wishes',
      provider: allWishesProvider,
      emptyMessage: 'No Wishes yet. Tap + to add your first aspiration.',
    );
  }
}

/// Wishes with lifecycle status Active (R9.2).
class ActiveWishesView extends StatelessWidget {
  const ActiveWishesView({super.key});

  @override
  Widget build(BuildContext context) {
    return WishListView(
      title: 'Active Wishes',
      provider: activeWishesProvider,
      emptyMessage: 'No active Wishes. New Wishes start here.',
    );
  }
}

/// Wishes with lifecycle status In_Progress (R9.3).
class InProgressWishesView extends StatelessWidget {
  const InProgressWishesView({super.key});

  @override
  Widget build(BuildContext context) {
    return WishListView(
      title: 'In-progress Wishes',
      provider: inProgressWishesProvider,
      emptyMessage: 'Nothing in progress yet. Start a Wish to see it here.',
    );
  }
}

/// Wishes with lifecycle status Completed (R9.4).
class CompletedWishesView extends StatelessWidget {
  const CompletedWishesView({super.key});

  @override
  Widget build(BuildContext context) {
    return WishListView(
      title: 'Completed Wishes',
      provider: completedWishesProvider,
      emptyMessage: 'No completed Wishes yet. Fulfilled Wishes land here.',
    );
  }
}
