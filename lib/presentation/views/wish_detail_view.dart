/// The Wish detail view (task 13.2) — the full-record screen opened when the
/// User taps a Wish from any list (R9.5).
///
/// ## Shape
///
/// [WishDetailView] is a [ConsumerWidget] parameterized by a [wishId]. It
/// resolves the Wish reactively by `watch`ing [allWishesProvider] and selecting
/// the matching record by id, so any mutation the User triggers here (progress,
/// start/complete/reopen) is reflected immediately when the underlying Drift
/// stream re-emits — no manual refresh. The surrounding `AsyncValue` drives the
/// loading / error states; a successfully-loaded list that contains no Wish
/// with [wishId] renders a friendly not-found panel (R9.5).
///
/// It renders ALL of the Wish's fields (R9.5): title, description, category,
/// priority, status, progress, and the UTC created / updated timestamps.
///
/// ## Actions (wired to [WishActionController])
///
///   - Progress — a slider (0–100, 5-step) committing on release via
///     `applyProgress(id, value)` (R5.1).
///   - Start — shown when the Wish is `Active`; `start(id)` (R6.2).
///   - Complete — shown when the Wish is not yet `Completed`; `complete(id)`
///     (R6.3).
///   - Reopen — shown when the Wish is `Completed`; `reopen(id)` (R6.4).
///   - Edit — navigates to [WishRoutes.editName].
///   - Delete — `requestDelete(id)`, then a confirmation [AlertDialog]; Confirm
///     calls `confirmDelete(request)` and navigates back to the list, Cancel
///     calls `cancelDelete(request)` (a no-op) (R8.2).
///
/// ## Layering (design "Module boundaries")
///
/// Presentation-layer only. It depends on the application layer (the
/// `allWishesProvider` stream and [wishActionControllerProvider]) and the
/// Drift-free domain models ([Wish], [Priority], [LifecycleStatus]); it never
/// imports Drift or `dart:io`.
library wishable.presentation.views.wish_detail_view;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/application.dart';
import '../../domain/domain.dart';
import '../router/app_router.dart';

/// Resolves the display name for a category id (R9.5).
///
/// A view-local [FutureProvider.family] that reads the one-shot category
/// snapshot through [categoryRepositoryProvider] (interface-typed, Drift-free)
/// and returns the matching category's name, or `null` if no category with the
/// id exists. Kept local to this view because the detail screen is the only
/// place that needs an id -> name lookup; the result is cached per id by
/// Riverpod so repeated reads do not re-query.
final FutureProviderFamily<String?, CategoryId> _categoryNameProvider =
    FutureProvider.family<String?, CategoryId>((Ref ref, CategoryId id) async {
  final List<Category> categories =
      await ref.watch(categoryRepositoryProvider).getAll();
  for (final Category category in categories) {
    if (category.id == id) {
      return category.name;
    }
  }
  return null;
});

/// Full-detail screen for a single Wish, resolved reactively by [wishId]
/// (R9.5). See the library doc for the fields rendered and the actions wired.
class WishDetailView extends ConsumerWidget {
  const WishDetailView({required this.wishId, super.key});

  /// The stable UUID of the Wish to display (R14.1).
  final WishId wishId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Wish>> wishes = ref.watch(allWishesProvider);
    // Resolve the stable display number for the title ("Wish #N"); falls back
    // to plain "Wish" while loading or if the number is unavailable.
    final int? seq = wishes.maybeWhen(
      data: (List<Wish> list) => _selectById(list, wishId)?.seq,
      orElse: () => null,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          seq == null ? 'Wish' : 'Wish #$seq',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.goNamed(
              WishRoutes.editName,
              pathParameters: <String, String>{'id': wishId},
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _onDelete(context, ref),
          ),
        ],
      ),
      body: wishes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            _DetailError(message: error.toString()),
        data: (List<Wish> list) {
          final Wish? wish = _selectById(list, wishId);
          if (wish == null) {
            return const _NotFound();
          }
          return _WishDetailBody(wish: wish);
        },
      ),
    );
  }

  /// Returns the Wish in [list] with id [id], or `null` if the Wish is absent
  /// (e.g. it was just deleted or never existed) — the not-found case (R9.5).
  static Wish? _selectById(List<Wish> list, WishId id) {
    for (final Wish wish in list) {
      if (wish.id == id) {
        return wish;
      }
    }
    return null;
  }

  /// Begins the confirmation-gated delete flow (R8.2): asks the controller for
  /// a [DeleteRequest], shows a confirmation [AlertDialog], and either confirms
  /// the delete and navigates back to the list, or cancels (a no-op).
  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final WishActionController controller =
        ref.read(wishActionControllerProvider);
    final DeleteRequest? request = await controller.requestDelete(wishId);
    if (request == null || !context.mounted) {
      // Nothing to delete (already gone) or the screen left the tree.
      return;
    }
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Delete Wish?'),
            content: Text(
              'Delete "${request.title}"? This cannot be undone.',
            ),
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
        ) ??
        false;

    if (confirmed) {
      await controller.confirmDelete(request);
      if (context.mounted) {
        // Confirmed delete removes the Wish (R8.1); return to the list so the
        // user is not left on a now-empty detail screen (R8.2).
        context.goNamed(WishRoutes.allName);
      }
    } else {
      // Cancel is a pure no-op by design (R8.3); the Wish is retained.
      controller.cancelDelete(request);
    }
  }
}

/// Renders every field of [wish] plus the progress control and lifecycle
/// action buttons (R9.5, R5.1, R6.2–R6.4).
class _WishDetailBody extends ConsumerWidget {
  const _WishDetailBody({required this.wish});

  final Wish wish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(wish.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _MetaChip(
              icon: _priorityIcon(wish.priority),
              label: 'Priority: ${_priorityLabel(wish.priority)}',
            ),
            _MetaChip(
              icon: _statusIcon(wish.status),
              label: 'Status: ${_statusLabel(wish.status)}',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Description (R9.5) — may be absent.
        const _FieldLabel('Description'),
        Text(
          (wish.description != null && wish.description!.isNotEmpty)
              ? wish.description!
              : 'No description',
          style: wish.description == null || wish.description!.isEmpty
              ? theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                )
              : theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),

        // Category (R9.5) — resolved to its display name, falling back to the
        // raw id if the category lookup has not yet loaded or is missing.
        const _FieldLabel('Category'),
        _CategoryName(categoryId: wish.categoryId),
        const SizedBox(height: 24),

        // Progress (R5.1) — reflects current value and lets the user adjust it.
        const _FieldLabel('Progress'),
        _ProgressControl(wish: wish),
        const SizedBox(height: 24),

        // Timestamps (R9.5, R14.2).
        const _FieldLabel('Created'),
        Text(_formatUtc(wish.createdAtUtc), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        const _FieldLabel('Last updated'),
        Text(_formatUtc(wish.updatedAtUtc), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 32),

        // Lifecycle actions (R6.2–R6.4).
        _LifecycleActions(wish: wish),
      ],
    );
  }

  /// Material Symbols glyph for a lifecycle [status].
  static IconData _statusIcon(LifecycleStatus status) => switch (status) {
        LifecycleStatus.active => Icons.star_outline,
        LifecycleStatus.inProgress => Icons.timelapse_outlined,
        LifecycleStatus.completed => Icons.check_circle_outline,
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

  /// Formats a UTC [DateTime] as an ISO-8601 string with a `Z` suffix so the
  /// User can see the exact stored instant (R14.2).
  static String _formatUtc(DateTime value) =>
      '${value.toUtc().toIso8601String()} (UTC)';
}

/// Resolves and displays a category's display name from its [categoryId] via
/// [_categoryNameProvider], falling back to the raw id while the lookup loads
/// or if the category is missing.
class _CategoryName extends ConsumerWidget {
  const _CategoryName({required this.categoryId});

  final CategoryId categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<String?> name =
        ref.watch(_categoryNameProvider(categoryId));
    // While the name resolves (or if the category is missing), fall back to the
    // raw id so the field always shows something concrete (R9.5).
    final String label = name.maybeWhen(
      data: (String? resolved) => resolved ?? categoryId,
      orElse: () => categoryId,
    );
    return Text(label, style: theme.textTheme.bodyMedium);
  }
}

/// A slider-based progress control that commits the chosen value on release via
/// [WishActionController.applyProgress] (R5.1).
///
/// Stateful so the thumb tracks the user's drag locally and only writes to the
/// repository once, on `onChangeEnd`. When the Wish re-emits with a new stored
/// progress, [didUpdateWidget] resyncs the local value so the control stays in
/// agreement with the source of truth.
class _ProgressControl extends ConsumerStatefulWidget {
  const _ProgressControl({required this.wish});

  final Wish wish;

  @override
  ConsumerState<_ProgressControl> createState() => _ProgressControlState();
}

class _ProgressControlState extends ConsumerState<_ProgressControl> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.wish.progress.clamp(0, 100).toDouble();
  }

  @override
  void didUpdateWidget(_ProgressControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wish.progress != widget.wish.progress) {
      _value = widget.wish.progress.clamp(0, 100).toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Slider(
            value: _value,
            max: 100,
            divisions: 20,
            label: '${_value.round()}%',
            onChanged: (double next) => setState(() => _value = next),
            onChangeEnd: (double next) {
              ref
                  .read(wishActionControllerProvider)
                  .applyProgress(widget.wish.id, next.round());
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            '${_value.round()}%',
            textAlign: TextAlign.end,
            style: theme.textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

/// Lifecycle action buttons for [wish], shown according to its current status
/// (R6.2–R6.4):
///
///   - `Active`     — Start, Complete
///   - `InProgress` — Complete
///   - `Completed`  — Reopen
class _LifecycleActions extends ConsumerWidget {
  const _LifecycleActions({required this.wish});

  final Wish wish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WishActionController controller =
        ref.read(wishActionControllerProvider);
    final List<Widget> buttons = <Widget>[];

    if (wish.status == LifecycleStatus.active) {
      // Start is only meaningful for an Active Wish (R6.2).
      buttons.add(
        FilledButton.tonalIcon(
          onPressed: () => controller.start(wish.id),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
        ),
      );
    }

    if (wish.status == LifecycleStatus.completed) {
      // Reopen is only meaningful for a Completed Wish (R6.4).
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => controller.reopen(wish.id),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reopen'),
        ),
      );
    } else {
      // Complete forces status to Completed and progress to 100 (R6.3).
      buttons.add(
        FilledButton.icon(
          onPressed: () => controller.complete(wish.id),
          icon: const Icon(Icons.check),
          label: const Text('Complete'),
        ),
      );
    }

    return Wrap(spacing: 12, runSpacing: 12, children: buttons);
  }
}

/// A small uppercase field label used to introduce each detail section.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// A compact icon + label pill used to show the Wish's priority and status.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly panel shown when the requested Wish does not exist (R9.5) — for
/// example after it has just been deleted.
class _NotFound extends StatelessWidget {
  const _NotFound();

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
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'This Wish is no longer available.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error panel shown when the wish stream emits an error.
class _DetailError extends StatelessWidget {
  const _DetailError({required this.message});

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
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong loading this Wish.',
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
