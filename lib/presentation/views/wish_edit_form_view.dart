/// The create / edit form view (task 13.3) — the screen used both to create a
/// new Wish (R1) and to edit an existing one (R2).
///
/// ## Shape
///
/// [WishEditFormView] is a [ConsumerStatefulWidget] parameterized by an
/// optional [wishId]:
///
///   - `null`      → create mode (`/wish/new`, R1): the form starts blank with
///                   priority defaulted to Medium (R1.4) and no category
///                   pre-selected.
///   - non-`null`  → edit mode (`/wish/:id/edit`, R2): the form resolves the
///                   existing Wish reactively (by `watch`ing [allWishesProvider]
///                   and selecting by id) and pre-fills every editable field
///                   from it. A not-found Wish renders a friendly panel.
///
/// ## Fields
///
///   - Title ([TextFormField]) — required (R1.1, R1.2). A blank title is
///     rejected by [WishValidator] and surfaced inline as "A title is
///     required." when the controller reports a [TitleRequiredError].
///   - Description ([TextFormField], multiline, optional) (R1.3, R2.3).
///   - Category — the User either picks an existing category from a
///     [DropdownButtonFormField] (loaded via [categoryRepositoryProvider]) or
///     chooses "New category…" and types a name. On submit the chosen/typed
///     name is resolved to a category id through
///     [CategoryRepository.getOrCreateByName], which reuses an existing
///     category or creates one, never duplicating (R3.1, R3.3).
///   - Priority — a segmented control over the [Priority] set, defaulting to
///     Medium in create mode (R1.4, R4.1).
///
/// Progress and lifecycle status are intentionally NOT part of this form: a new
/// Wish always starts Active at 0 (R1.1), and edits of progress/status flow
/// through the detail view's `WishActionController` rather than through a
/// [WishEdit] (which carries only title/description/category/priority).
///
/// ## Submit
///
/// On submit the form resolves the category id, builds a [WishDraft] (create)
/// or [WishEdit] (edit), and calls [WishEditController.createWish] /
/// [WishEditController.editWish]. The form `watch`es
/// [wishEditControllerProvider]:
///
///   - [WishEditInvalid] → the errors are surfaced inline (a
///     [TitleRequiredError] under the title field; any other error as a general
///     banner) (R1.2).
///   - [WishEditSaved]   → the form navigates back (`context.pop`, falling back
///     to the list) so the User returns to where they came from.
///
/// ## Layering (design "Module boundaries")
///
/// Presentation-layer only. It depends on the application layer
/// ([wishEditControllerProvider], [allWishesProvider],
/// [categoryRepositoryProvider]) and the Drift-free domain models ([Wish],
/// [Category], [Priority], [WishDraft], [WishEdit], [ValidationError]); it never
/// imports Drift or `dart:io`.
library wishable.presentation.views.wish_edit_form_view;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/application.dart';
import '../../domain/domain.dart';
import '../router/app_router.dart';

/// Loads the available categories as a one-shot snapshot for the picker
/// (R3.1). A view-local [FutureProvider] over the interface-typed, Drift-free
/// [categoryRepositoryProvider]; Riverpod caches the result for the life of the
/// form.
final FutureProvider<List<Category>> _categoriesProvider =
    FutureProvider<List<Category>>(
  (Ref ref) => ref.watch(categoryRepositoryProvider).getAll(),
  name: 'wishEditForm.categoriesProvider',
);

/// Create / edit form for a single Wish (R1, R2). A `null` [wishId] means
/// create; a non-null id means edit the identified Wish.
class WishEditFormView extends ConsumerWidget {
  const WishEditFormView({required this.wishId, super.key});

  /// The stable UUID of the Wish to edit, or `null` to create a new Wish.
  final WishId? wishId;

  bool get _isCreate => wishId == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Create mode needs no existing Wish — build the form immediately.
    if (_isCreate) {
      return const _FormScaffold(
        title: 'New Wish',
        child: _WishForm(existing: null),
      );
    }

    // Edit mode: resolve the existing Wish reactively, mirroring the detail
    // view so the form always reflects the stored record (R2).
    final AsyncValue<List<Wish>> wishes = ref.watch(allWishesProvider);
    return _FormScaffold(
      title: 'Edit Wish',
      child: wishes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            _FormMessage(message: error.toString(), isError: true),
        data: (List<Wish> list) {
          final Wish? existing = _selectById(list, wishId!);
          if (existing == null) {
            return const _FormMessage(
              message: 'This Wish is no longer available.',
            );
          }
          return _WishForm(existing: existing);
        },
      ),
    );
  }

  /// Returns the Wish in [list] with id [id], or `null` when absent (R2
  /// not-found case).
  static Wish? _selectById(List<Wish> list, WishId id) {
    for (final Wish wish in list) {
      if (wish.id == id) {
        return wish;
      }
    }
    return null;
  }
}

/// Scaffolds the form chrome (app bar + padded body) shared by create and edit.
class _FormScaffold extends StatelessWidget {
  const _FormScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

/// The stateful form body. Owns the text controllers, the category selection,
/// and the chosen priority; drives [WishEditController] on submit and surfaces
/// its validation result inline.
class _WishForm extends ConsumerStatefulWidget {
  const _WishForm({required this.existing});

  /// The Wish being edited, or `null` in create mode.
  final Wish? existing;

  @override
  ConsumerState<_WishForm> createState() => _WishFormState();
}

/// Sentinel category id meaning "create a new category from the typed name".
const String _newCategorySentinel = '__new_category__';

class _WishFormState extends ConsumerState<_WishForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final TextEditingController _newCategoryController = TextEditingController();

  /// The currently selected existing category id, or [_newCategorySentinel]
  /// when the User is entering a new category name. `null` means nothing is
  /// selected yet (create mode, before the categories load).
  String? _selectedCategoryId;

  /// The chosen priority; defaults to Medium in create mode (R1.4, R4.1).
  late Priority _priority;

  bool get _isCreate => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final Wish? existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _selectedCategoryId = existing?.categoryId;
    _priority = existing?.priority ?? kDefaultPriority;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // React to the controller's outcome: navigate away on save, otherwise fall
    // through to render any inline errors below.
    ref.listen<AsyncValue<WishEditState>>(
      wishEditControllerProvider,
      (AsyncValue<WishEditState>? previous, AsyncValue<WishEditState> next) {
        if (next.value is WishEditSaved && context.mounted) {
          _goBack();
        }
      },
    );

    final AsyncValue<WishEditState> editState =
        ref.watch(wishEditControllerProvider);
    final bool isSaving = editState.isLoading;
    final List<ValidationError> errors = _errorsFrom(editState);
    final String? titleError =
        errors.any((ValidationError e) => e is TitleRequiredError)
            ? const TitleRequiredError().message
            : null;
    final List<ValidationError> otherErrors = errors
        .where((ValidationError e) => e is! TitleRequiredError)
        .toList(growable: false);

    final AsyncValue<List<Category>> categories =
        ref.watch(_categoriesProvider);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (otherErrors.isNotEmpty) ...<Widget>[
            _ErrorBanner(
              message:
                  otherErrors.map((ValidationError e) => e.message).join('\n'),
            ),
            const SizedBox(height: 16),
          ],

          // Title (required) — R1.1, R1.2.
          TextFormField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            autofocus: _isCreate,
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: 'What do you wish for?',
              border: const OutlineInputBorder(),
              errorText: titleError,
            ),
          ),
          const SizedBox(height: 16),

          // Description (optional, multiline) — R1.3, R2.3.
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Category — pick existing or create new (R3.1, R3.3).
          const _FieldLabel('Category'),
          categories.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            error: (Object error, StackTrace _) => _ErrorBanner(
              message: 'Could not load categories: $error',
            ),
            data: (List<Category> list) => _buildCategoryPicker(list),
          ),
          const SizedBox(height: 24),

          // Priority — segmented control defaulting to Medium (R1.4, R4.1).
          const _FieldLabel('Priority'),
          const SizedBox(height: 4),
          _PrioritySelector(
            value: _priority,
            onChanged: (Priority next) => setState(() => _priority = next),
          ),
          const SizedBox(height: 32),

          FilledButton.icon(
            onPressed: isSaving ? null : _submit,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isCreate ? 'Create Wish' : 'Save changes'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: isSaving ? null : _goBack,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Builds the category dropdown plus, when "New category…" is selected, a
  /// text field for the new name. The dropdown lists every existing category
  /// and a trailing sentinel entry for creating a new one.
  Widget _buildCategoryPicker(List<Category> list) {
    // If an edit refers to a category not in the snapshot (edge case), keep the
    // id selectable so the dropdown has a valid value.
    final bool selectionKnown = _selectedCategoryId == null ||
        _selectedCategoryId == _newCategorySentinel ||
        list.any((Category c) => c.id == _selectedCategoryId);
    final String? effectiveValue = selectionKnown ? _selectedCategoryId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: effectiveValue,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Choose a category',
          ),
          items: <DropdownMenuItem<String>>[
            for (final Category category in list)
              DropdownMenuItem<String>(
                value: category.id,
                child: Text(category.name),
              ),
            const DropdownMenuItem<String>(
              value: _newCategorySentinel,
              child: Text('New category…'),
            ),
          ],
          onChanged: (String? next) =>
              setState(() => _selectedCategoryId = next),
        ),
        if (_selectedCategoryId == _newCategorySentinel) ...<Widget>[
          const SizedBox(height: 12),
          TextFormField(
            controller: _newCategoryController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'New category name',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }

  /// Resolves the chosen category to a concrete id, builds the draft/edit, and
  /// invokes the controller. Category resolution uses
  /// [CategoryRepository.getOrCreateByName] so a typed name reuses an existing
  /// category or creates one without duplicating (R3.1, R3.3).
  Future<void> _submit() async {
    final String? categoryId = await _resolveCategoryId();
    if (categoryId == null) {
      // No category chosen (and no name typed) — prompt the User and stop.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose or name a category.')),
        );
      }
      return;
    }

    final String title = _titleController.text;
    final String rawDescription = _descriptionController.text.trim();
    final String? description = rawDescription.isEmpty ? null : rawDescription;

    final WishEditController controller =
        ref.read(wishEditControllerProvider.notifier);

    if (_isCreate) {
      await controller.createWish(
        WishDraft(
          title: title,
          description: description,
          categoryId: categoryId,
          priority: _priority,
        ),
      );
    } else {
      await controller.editWish(
        widget.existing!.id,
        WishEdit(
          title: title,
          description: description,
          categoryId: categoryId,
          priority: _priority,
        ),
      );
    }
    // Navigation on success is handled by the `ref.listen` on WishEditSaved;
    // validation failures re-render this form with inline errors.
  }

  /// Resolves the selected/typed category to an id, or `null` when the User has
  /// neither selected an existing category nor typed a new name.
  Future<String?> _resolveCategoryId() async {
    final String? selection = _selectedCategoryId;
    if (selection != null && selection != _newCategorySentinel) {
      return selection;
    }

    // "New category…" path: resolve the typed name via get-or-create (R3.3).
    final String name = _newCategoryController.text.trim();
    if (name.isEmpty) {
      return null;
    }
    final Category category =
        await ref.read(categoryRepositoryProvider).getOrCreateByName(name);
    return category.id;
  }

  /// Navigates back after a save or cancel, falling back to the all-wishes list
  /// when there is no route to pop (e.g. deep-linked straight into the form).
  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(WishRoutes.allName);
    }
  }

  /// Extracts the validation errors from the controller state, or an empty list
  /// when the state is not [WishEditInvalid].
  static List<ValidationError> _errorsFrom(AsyncValue<WishEditState> state) {
    final WishEditState? value = state.value;
    if (value is WishEditInvalid) {
      return value.errors;
    }
    return const <ValidationError>[];
  }
}

/// A segmented control over the [Priority] set (Low / Medium / High) (R4.1).
class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.value, required this.onChanged});

  final Priority value;
  final ValueChanged<Priority> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Priority>(
      segments: const <ButtonSegment<Priority>>[
        ButtonSegment<Priority>(
          value: Priority.low,
          label: Text('Low'),
          icon: Icon(Icons.keyboard_double_arrow_down),
        ),
        ButtonSegment<Priority>(
          value: Priority.medium,
          label: Text('Medium'),
          icon: Icon(Icons.drag_handle),
        ),
        ButtonSegment<Priority>(
          value: Priority.high,
          label: Text('High'),
          icon: Icon(Icons.keyboard_double_arrow_up),
        ),
      ],
      selected: <Priority>{value},
      onSelectionChanged: (Set<Priority> selection) =>
          onChanged(selection.first),
    );
  }
}

/// A small uppercase field label matching the detail view's section headers.
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

/// An inline error banner for non-title validation errors (R1.2) and category
/// load failures.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A centred message panel for the edit not-found and stream-error cases.
class _FormMessage extends StatelessWidget {
  const _FormMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

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
              isError ? Icons.error_outline : Icons.search_off,
              size: 48,
              color: isError
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
