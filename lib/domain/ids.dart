/// Strongly-named identifier aliases for the domain layer.
///
/// The design's data-access signatures refer to `WishId` and `CategoryId`
/// (design "Data-Access Layer (repositories)"). Identifiers are stable UUID
/// v4 strings (R14.1), so these are plain aliases over [String]: they document
/// intent at call sites and interface signatures without introducing a wrapper
/// type or any dependency beyond Dart core.
///
/// Pure Dart: no Flutter, Drift, or dart:io dependencies.
library wishable.domain.ids;

/// Identifies a [Wish] by its stable UUID (R14.1).
typedef WishId = String;

/// Identifies a [Category] by its stable UUID.
typedef CategoryId = String;
