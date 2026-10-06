/// [WishImageGallery] — displays and manages the images attached to a Wish.
///
/// Shown on the Wish detail view. Renders a horizontal strip of image
/// thumbnails (from the locally-cached bytes, so it works offline and on web),
/// an "Add image" button that picks one or more images via `file_picker`, and a
/// delete affordance per image with confirmation.
///
/// Presentation-layer only: depends on the application layer
/// ([wishImagesProvider], [wishImageControllerProvider]) and the domain
/// [WishImage] type; it never imports Drift. Image bytes are read at the picker
/// edge (`withData: true`) so no `dart:io`/path_provider is needed.
library wishable.presentation.views.wish_image_gallery;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/application.dart';
import '../../domain/domain.dart';

/// A gallery + manager for the images of the Wish identified by [wishId].
class WishImageGallery extends ConsumerWidget {
  const WishImageGallery({required this.wishId, super.key});

  final WishId wishId;

  Future<void> _pickAndAdd(BuildContext context, WidgetRef ref) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true, // load bytes directly (works on web + native)
    );
    if (result == null) return;
    final WishImageController controller =
        ref.read(wishImageControllerProvider);
    for (final PlatformFile file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      await controller.add(wishId, bytes, _mimeFromName(file.name));
    }
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, WishImage image) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Remove image?'),
        content: const Text('This image will be removed from the wishlist.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(wishImageControllerProvider).remove(image.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<WishImage>> images =
        ref.watch(wishImagesProvider(wishId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Images', style: theme.textTheme.titleMedium),
            TextButton.icon(
              onPressed: () => _pickAndAdd(context, ref),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        images.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object e, StackTrace _) => Text(
            'Could not load images.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
          data: (List<WishImage> list) {
            if (list.isEmpty) {
              return _EmptyImages(onAdd: () => _pickAndAdd(context, ref));
            }
            return SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (BuildContext context, int index) {
                  final WishImage img = list[index];
                  return _Thumbnail(
                    image: img,
                    onRemove: () => _confirmRemove(context, ref, img),
                    onTap: () => _openViewer(context, list, index),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _openViewer(BuildContext context, List<WishImage> images, int index) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(images[index].bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }

  static String _mimeFromName(String name) {
    final String n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.image,
    required this.onRemove,
    required this.onTap,
  });

  final WishImage image;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              image.bytes,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close,
                    size: 18, color: theme.colorScheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyImages extends StatelessWidget {
  const _EmptyImages({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.add_photo_alternate_outlined,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text('Add an image',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
