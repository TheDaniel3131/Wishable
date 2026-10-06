/// Image providers + controller for a Wish's attached images.
///
/// Exposes reactive image lists (per Wish, and a cover thumbnail) and the
/// imperative add/remove actions the UI triggers. Depends only on the
/// Drift-free [WishImageRepository] interface and the domain [WishImage] type
/// (R14.3); it never imports Drift or a file plugin — image bytes are passed in
/// by the picker at the presentation edge.
library wishable.application.controllers.wish_image_controller;

import 'dart:typed_data';

import 'package:riverpod/riverpod.dart';

import '../../data/repositories/wish_image_repository.dart';
import '../../domain/ids.dart';
import '../../domain/wish_image.dart';
import '../providers.dart';

/// Watches the ordered list of images for a given Wish id.
final StreamProviderFamily<List<WishImage>, WishId> wishImagesProvider =
    StreamProvider.family<List<WishImage>, WishId>(
  (Ref ref, WishId wishId) {
    ref.keepAlive();
    return ref.watch(wishImageRepositoryProvider).watchForWish(wishId);
  },
  name: 'wishImagesProvider',
);

/// Watches the cover (first) image for a Wish id, or null when it has none.
/// Used by list rows for a lightweight thumbnail.
final StreamProviderFamily<WishImage?, WishId> wishCoverImageProvider =
    StreamProvider.family<WishImage?, WishId>(
  (Ref ref, WishId wishId) {
    ref.keepAlive();
    return ref.watch(wishImageRepositoryProvider).watchCover(wishId);
  },
  name: 'wishCoverImageProvider',
);

/// Drives add/remove of a Wish's images through the repository.
final class WishImageController {
  WishImageController(this._ref);

  final Ref _ref;

  WishImageRepository get _repository =>
      _ref.read(wishImageRepositoryProvider);

  /// Adds an image from raw [bytes] (as picked by the UI) to [wishId].
  Future<WishImage> add(WishId wishId, Uint8List bytes, String mimeType) {
    return _repository.add(wishId, bytes, mimeType);
  }

  /// Removes the image identified by [imageId].
  Future<void> remove(String imageId) => _repository.remove(imageId);
}

/// Provides the [WishImageController].
final Provider<WishImageController> wishImageControllerProvider =
    Provider<WishImageController>(
  WishImageController.new,
  name: 'wishImageControllerProvider',
);
