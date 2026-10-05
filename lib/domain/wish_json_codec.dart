/// Pure JSON serializer/parser for the Wishable backup format.
///
/// This codec implements the **JSON_Export** format from the design
/// ("Serialization formats"): a schema-versioned envelope carrying a `wishes`
/// array. It is a pure Dart unit in the domain layer — no Flutter, Drift, or
/// dart:io dependencies — so it can be reused by the data-access
/// `BackupService` and exercised by round-trip property tests (R12.4).
///
/// ## Category by name
///
/// The persisted [Wish] stores a `categoryId` foreign key, but the export
/// format embeds the category **by name** so an import on a fresh install can
/// recreate categories that do not yet exist (design "Serialization formats").
/// To keep this codec pure and round-trippable it operates on a small
/// serializable projection — [SerializableWish] — that carries the category
/// NAME rather than its id. The data layer is responsible for mapping between
/// `categoryId` and category name when it builds/consumes these projections.
///
/// ## Encoding rules (design "Serialization formats")
///
///   - Timestamps are ISO-8601 UTC strings (e.g. `2025-01-01T00:00:00.000Z`).
///   - Enums serialize as stable lowercase tokens:
///       * [Priority]:        `low`, `medium`, `high`
///       * [LifecycleStatus]: `active`, `in_progress`, `completed`
///   - Categories are embedded by name.
///   - A top-level `schemaVersion` and `exportedAtUtc` accompany the `wishes`
///     array.
///
/// Decoding rejects malformed structure, unknown enum tokens, and unparseable
/// timestamps with descriptive [WishJsonFormatException]s (R12.1, R4.3).
library wishable.domain.wish_json_codec;

import 'dart:convert';

import 'lifecycle_status.dart';
import 'priority.dart';
import 'wish.dart';

/// The schema version written by [WishJsonCodec.encode] and the only version
/// [WishJsonCodec.decode] accepts.
const int kWishJsonSchemaVersion = 1;

/// A serializable projection of a [Wish] that embeds the owning category by
/// NAME instead of by id (design "Serialization formats").
///
/// This is the unit the [WishJsonCodec] reads and writes. It mirrors every
/// domain field of a [Wish] except that `categoryId` is replaced by
/// [categoryName]. The data-access layer resolves names to ids (and back)
/// around the codec, keeping the codec itself pure and free of any id lookup.
///
/// Compared by value so round-trip equivalence (R12.4) can be asserted
/// directly on the decoded list, independent of ordering.
final class SerializableWish {
  const SerializableWish({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryName,
    required this.priority,
    required this.status,
    required this.progress,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  /// Builds a [SerializableWish] from a [Wish] and the resolved name of its
  /// owning category.
  factory SerializableWish.fromWish(Wish wish, {required String categoryName}) {
    return SerializableWish(
      id: wish.id,
      title: wish.title,
      description: wish.description,
      categoryName: categoryName,
      priority: wish.priority,
      status: wish.status,
      progress: wish.progress,
      createdAtUtc: wish.createdAtUtc,
      updatedAtUtc: wish.updatedAtUtc,
    );
  }

  /// Stable UUID of the Wish (R14.1).
  final String id;

  /// Non-empty title (R1.2).
  final String title;

  /// Optional description (R1.3); `null` when absent.
  final String? description;

  /// Name of the owning category, embedded for recreate-on-import.
  final String categoryName;

  /// Priority ranking (R4).
  final Priority priority;

  /// Lifecycle status (R6).
  final LifecycleStatus status;

  /// Progress in the inclusive range [0, 100] (R5).
  final int progress;

  /// Creation timestamp in UTC (R1.5, R14.2).
  final DateTime createdAtUtc;

  /// Last-modified timestamp in UTC (R2.4, R14.2).
  final DateTime updatedAtUtc;

  /// Rebuilds a [Wish] from this projection given the resolved [categoryId]
  /// for [categoryName].
  Wish toWish({required String categoryId}) {
    return Wish(
      id: id,
      title: title,
      description: description,
      categoryId: categoryId,
      priority: priority,
      status: status,
      progress: progress,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SerializableWish &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.categoryName == categoryName &&
          other.priority == priority &&
          other.status == status &&
          other.progress == progress &&
          other.createdAtUtc == createdAtUtc &&
          other.updatedAtUtc == updatedAtUtc;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        categoryName,
        priority,
        status,
        progress,
        createdAtUtc,
        updatedAtUtc,
      );

  @override
  String toString() => 'SerializableWish(id: $id, title: $title, '
      'description: $description, categoryName: $categoryName, '
      'priority: $priority, status: $status, progress: $progress, '
      'createdAtUtc: $createdAtUtc, updatedAtUtc: $updatedAtUtc)';
}

/// Thrown when [WishJsonCodec.decode] encounters content it cannot parse: an
/// invalid top-level structure, a missing/misshapen field, an unknown enum
/// token, or an unparseable timestamp (R12.1, R4.3).
///
/// The [message] is a human-readable description suitable for surfacing to the
/// user. [path] points at the offending location (e.g. `wishes[2].priority`)
/// when known, to make import failures diagnosable.
final class WishJsonFormatException implements Exception {
  const WishJsonFormatException(this.message, {this.path});

  /// Human-readable description of what went wrong.
  final String message;

  /// Dotted/indexed path to the offending element, when known.
  final String? path;

  @override
  String toString() {
    final where = path == null ? '' : ' (at $path)';
    return 'WishJsonFormatException: $message$where';
  }
}

/// Pure JSON codec for the Wishable backup format (design "Serialization
/// formats", JSON_Export).
///
/// [encode] produces the canonical schema-versioned string; [decode] parses it
/// back into a list of [SerializableWish], rejecting malformed input with a
/// descriptive [WishJsonFormatException]. The two are inverse up to ordering
/// and the embedded `exportedAtUtc` stamp (R12.4).
final class WishJsonCodec {
  const WishJsonCodec();

  // --- Enum token tables (stable lowercase tokens, design "Serialization
  // formats"). Kept explicit so a future enum reorder cannot silently change
  // the wire format.

  static const Map<Priority, String> _priorityTokens = {
    Priority.low: 'low',
    Priority.medium: 'medium',
    Priority.high: 'high',
  };

  static const Map<String, Priority> _priorityByToken = {
    'low': Priority.low,
    'medium': Priority.medium,
    'high': Priority.high,
  };

  static const Map<LifecycleStatus, String> _statusTokens = {
    LifecycleStatus.active: 'active',
    LifecycleStatus.inProgress: 'in_progress',
    LifecycleStatus.completed: 'completed',
  };

  static const Map<String, LifecycleStatus> _statusByToken = {
    'active': LifecycleStatus.active,
    'in_progress': LifecycleStatus.inProgress,
    'completed': LifecycleStatus.completed,
  };

  /// Encodes [wishes] into the canonical JSON string.
  ///
  /// [exportedAtUtc] stamps the envelope; it is coerced to UTC so the output
  /// is always an ISO-8601 UTC string regardless of the caller's timezone.
  /// Defaults to [DateTime.now] (in UTC) when omitted.
  String encode(List<SerializableWish> wishes, {DateTime? exportedAtUtc}) {
    final stamp = (exportedAtUtc ?? DateTime.now()).toUtc();
    final map = <String, Object?>{
      'schemaVersion': kWishJsonSchemaVersion,
      'exportedAtUtc': _encodeTimestamp(stamp),
      'wishes': [for (final w in wishes) _encodeWish(w)],
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Decodes [source] produced by [encode] back into a list of
  /// [SerializableWish].
  ///
  /// Throws [WishJsonFormatException] when [source] is not valid JSON, is not
  /// the expected object shape, declares an unsupported `schemaVersion`, or
  /// contains a wish with a missing/invalid field, an unknown enum token, or
  /// an unparseable timestamp.
  List<SerializableWish> decode(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (e) {
      throw WishJsonFormatException('Source is not valid JSON: ${e.message}');
    }

    final map = _asObject(root, 'root');

    final version = _asInt(map['schemaVersion'], 'schemaVersion');
    if (version != kWishJsonSchemaVersion) {
      throw WishJsonFormatException(
        'Unsupported schemaVersion $version; '
        'expected $kWishJsonSchemaVersion.',
        path: 'schemaVersion',
      );
    }

    final rawWishes = map['wishes'];
    if (rawWishes is! List) {
      throw const WishJsonFormatException(
        "Field 'wishes' must be a JSON array.",
        path: 'wishes',
      );
    }

    final result = <SerializableWish>[];
    for (var i = 0; i < rawWishes.length; i++) {
      result.add(_decodeWish(rawWishes[i], 'wishes[$i]'));
    }
    return result;
  }

  // --- Encoding helpers ---

  Map<String, Object?> _encodeWish(SerializableWish w) {
    return <String, Object?>{
      'id': w.id,
      'title': w.title,
      'description': w.description,
      'category': w.categoryName,
      'priority': _priorityTokens[w.priority],
      'status': _statusTokens[w.status],
      'progress': w.progress,
      'createdAtUtc': _encodeTimestamp(w.createdAtUtc),
      'updatedAtUtc': _encodeTimestamp(w.updatedAtUtc),
    };
  }

  /// Formats [value] as an ISO-8601 UTC string (always ending in `Z`).
  static String _encodeTimestamp(DateTime value) =>
      value.toUtc().toIso8601String();

  // --- Decoding helpers ---

  SerializableWish _decodeWish(Object? raw, String path) {
    final map = _asObject(raw, path);
    return SerializableWish(
      id: _asString(map['id'], '$path.id'),
      title: _asString(map['title'], '$path.title'),
      description: _asNullableString(map['description'], '$path.description'),
      categoryName: _asString(map['category'], '$path.category'),
      priority: _decodePriority(map['priority'], '$path.priority'),
      status: _decodeStatus(map['status'], '$path.status'),
      progress: _asInt(map['progress'], '$path.progress'),
      createdAtUtc: _decodeTimestamp(map['createdAtUtc'], '$path.createdAtUtc'),
      updatedAtUtc: _decodeTimestamp(map['updatedAtUtc'], '$path.updatedAtUtc'),
    );
  }

  Priority _decodePriority(Object? raw, String path) {
    final token = _asString(raw, path);
    final value = _priorityByToken[token];
    if (value == null) {
      throw WishJsonFormatException(
        "Unknown priority token '$token'; "
        "expected one of ${_priorityByToken.keys.join(', ')}.",
        path: path,
      );
    }
    return value;
  }

  LifecycleStatus _decodeStatus(Object? raw, String path) {
    final token = _asString(raw, path);
    final value = _statusByToken[token];
    if (value == null) {
      throw WishJsonFormatException(
        "Unknown status token '$token'; "
        "expected one of ${_statusByToken.keys.join(', ')}.",
        path: path,
      );
    }
    return value;
  }

  DateTime _decodeTimestamp(Object? raw, String path) {
    final text = _asString(raw, path);
    final DateTime parsed;
    try {
      parsed = DateTime.parse(text);
    } on FormatException {
      throw WishJsonFormatException(
        "Timestamp '$text' is not a valid ISO-8601 date-time.",
        path: path,
      );
    }
    return parsed.toUtc();
  }

  // --- Primitive extractors (each raises a descriptive, path-aware error) ---

  Map<String, Object?> _asObject(Object? raw, String path) {
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map) return raw.cast<String, Object?>();
    throw WishJsonFormatException(
      'Expected a JSON object but found ${_typeName(raw)}.',
      path: path,
    );
  }

  String _asString(Object? raw, String path) {
    if (raw is String) return raw;
    throw WishJsonFormatException(
      'Expected a string but found ${_typeName(raw)}.',
      path: path,
    );
  }

  String? _asNullableString(Object? raw, String path) {
    if (raw == null) return null;
    if (raw is String) return raw;
    throw WishJsonFormatException(
      'Expected a string or null but found ${_typeName(raw)}.',
      path: path,
    );
  }

  int _asInt(Object? raw, String path) {
    if (raw is int) return raw;
    throw WishJsonFormatException(
      'Expected an integer but found ${_typeName(raw)}.',
      path: path,
    );
  }

  static String _typeName(Object? raw) {
    if (raw == null) return 'null';
    if (raw is List) return 'an array';
    if (raw is Map) return 'an object';
    if (raw is String) return 'a string';
    if (raw is bool) return 'a boolean';
    if (raw is num) return 'a number';
    return raw.runtimeType.toString();
  }
}
