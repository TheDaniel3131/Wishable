/// Pure CSV serializer/parser for the Wishable backup format.
///
/// This codec implements the **CSV_Export** format from the design
/// ("Serialization formats"): a header row followed by one row per Wish, with
/// the same fields in a fixed column order. Like [WishJsonCodec] it is a pure
/// Dart unit in the domain layer — no Flutter, Drift, or dart:io dependencies —
/// so it can be reused by the data-access `BackupService` and exercised by
/// round-trip property tests (R12.5).
///
/// ## Shared projection and encoding rules
///
/// This codec reads and writes the same [SerializableWish] projection as the
/// JSON codec (it carries the category by NAME, see [SerializableWish]). To
/// keep the two export formats interchangeable it reuses the identical
/// encodings (design "Serialization formats"):
///
///   - Timestamps are ISO-8601 UTC strings (e.g. `2025-01-01T00:00:00.000Z`).
///   - Enums serialize as stable lowercase tokens:
///       * [Priority]:        `low`, `medium`, `high`
///       * [LifecycleStatus]: `active`, `in_progress`, `completed`
///   - Categories are embedded by name.
///
/// ## Column order
///
/// Every row has exactly nine columns in this fixed order (design
/// "Serialization formats"):
///
///   `id, title, description, category, priority, status, progress,
///    createdAtUtc, updatedAtUtc`
///
/// ## RFC-4180 quoting
///
/// Fields are written and read with RFC-4180 rules, implemented inline (no
/// external CSV package): a field is wrapped in double quotes when it contains
/// a comma, a double quote, a carriage return, or a line feed, and any
/// embedded double quote is doubled (`"` → `""`). This lets titles and
/// descriptions carrying commas, quotes, and newlines survive a round trip
/// (R11.3, R12.5).
///
/// ## Nullable description
///
/// The domain distinguishes an absent description (`null`) from an empty one
/// (`''`), and the round-trip equivalence definition compares the two
/// (design "Serialization formats"). CSV has no native null, so this codec
/// uses quoting to carry the distinction losslessly:
///
///   - `null`  → an empty, UNQUOTED field.
///   - `''`    → an empty, QUOTED field (`""`).
///
/// Every other string field is also distinguishable because any non-null,
/// non-empty value is emitted verbatim (quoted only when it must be), and a
/// quoted empty field decodes back to `''` while a bare empty field decodes to
/// `null`.
///
/// Decoding rejects malformed rows, wrong column counts, unknown enum tokens,
/// non-integer progress, and unparseable timestamps with descriptive
/// [WishCsvFormatException]s (R12.1).
library wishable.domain.wish_csv_codec;

import 'lifecycle_status.dart';
import 'priority.dart';
import 'wish_json_codec.dart' show SerializableWish;

/// Thrown when [WishCsvCodec.decode] encounters content it cannot parse: an
/// unterminated quoted field, a row with the wrong number of columns, a bad
/// header, an unknown enum token, a non-integer progress, or an unparseable
/// timestamp (R12.1).
///
/// The [message] is a human-readable description suitable for surfacing to the
/// user. [line] is the 1-based record number (the header is line 1) when
/// known, and [column] is the fixed-column name (e.g. `priority`) when the
/// failure is attributable to a single field — together they make import
/// failures diagnosable.
final class WishCsvFormatException implements Exception {
  const WishCsvFormatException(this.message, {this.line, this.column});

  /// Human-readable description of what went wrong.
  final String message;

  /// 1-based record number (header is 1), when known.
  final int? line;

  /// Fixed-column name of the offending field, when known.
  final String? column;

  @override
  String toString() {
    final buffer = StringBuffer('WishCsvFormatException: $message');
    if (line != null || column != null) {
      buffer.write(' (at');
      if (line != null) buffer.write(' line $line');
      if (column != null) buffer.write(" column '$column'");
      buffer.write(')');
    }
    return buffer.toString();
  }
}

/// Pure CSV codec for the Wishable backup format (design "Serialization
/// formats", CSV_Export).
///
/// [encode] produces the canonical header-plus-rows string; [decode] parses it
/// back into a list of [SerializableWish], rejecting malformed input with a
/// descriptive [WishCsvFormatException]. The two are inverse up to ordering
/// (R12.5).
final class WishCsvCodec {
  const WishCsvCodec();

  /// The fixed column order shared by [encode] and [decode] (design
  /// "Serialization formats").
  static const List<String> columns = <String>[
    'id',
    'title',
    'description',
    'category',
    'priority',
    'status',
    'progress',
    'createdAtUtc',
    'updatedAtUtc',
  ];

  /// Rows are terminated with CRLF, the RFC-4180 record separator.
  static const String _recordSeparator = '\r\n';

  // --- Enum token tables (stable lowercase tokens, design "Serialization
  // formats"). Mirrors the JSON codec so the two formats are interchangeable.

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

  /// Encodes [wishes] into the canonical CSV string: a header row followed by
  /// one row per wish, each terminated with CRLF.
  String encode(List<SerializableWish> wishes) {
    final buffer = StringBuffer();
    buffer
      ..write(_encodeRow([for (final name in columns) _Field.value(name)]))
      ..write(_recordSeparator);
    for (final w in wishes) {
      buffer
        ..write(_encodeRow(_fieldsOf(w)))
        ..write(_recordSeparator);
    }
    return buffer.toString();
  }

  /// Decodes [source] produced by [encode] back into a list of
  /// [SerializableWish].
  ///
  /// Throws [WishCsvFormatException] when [source] has a malformed header, a
  /// row with the wrong column count, an unterminated quoted field, an unknown
  /// enum token, a non-integer progress, or an unparseable timestamp. A
  /// trailing record separator (and a final empty line) is tolerated.
  List<SerializableWish> decode(String source) {
    final records = _parseRecords(source);
    if (records.isEmpty) {
      throw const WishCsvFormatException(
        'CSV is empty; expected at least a header row.',
        line: 1,
      );
    }

    _validateHeader(records.first);

    final result = <SerializableWish>[];
    for (var i = 1; i < records.length; i++) {
      // +1 so the user-facing line number is 1-based including the header.
      result.add(_decodeRow(records[i], line: i + 1));
    }
    return result;
  }

  // --- Encoding helpers ---

  List<_Field> _fieldsOf(SerializableWish w) {
    return <_Field>[
      _Field.value(w.id),
      _Field.value(w.title),
      // null description -> empty unquoted; '' -> empty quoted.
      w.description == null ? _Field.absent() : _Field.value(w.description!),
      _Field.value(w.categoryName),
      _Field.value(_priorityTokens[w.priority]!),
      _Field.value(_statusTokens[w.status]!),
      _Field.value(w.progress.toString()),
      _Field.value(_encodeTimestamp(w.createdAtUtc)),
      _Field.value(_encodeTimestamp(w.updatedAtUtc)),
    ];
  }

  String _encodeRow(List<_Field> fields) {
    return fields.map(_encodeField).join(',');
  }

  /// Applies RFC-4180 quoting. An [_Field.absent] field is emitted as a bare
  /// empty string; every present value is quoted only when it contains a
  /// comma, double quote, CR, or LF, OR when it is the empty string (so an
  /// empty description `''` is distinguishable from an absent one).
  String _encodeField(_Field field) {
    if (field.isAbsent) return '';
    final value = field.value;
    final mustQuote = value.isEmpty ||
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\r') ||
        value.contains('\n');
    if (!mustQuote) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  static String _encodeTimestamp(DateTime value) =>
      value.toUtc().toIso8601String();

  // --- Decoding helpers ---

  void _validateHeader(_Record header) {
    final fields = header.fields;
    if (fields.length != columns.length) {
      throw WishCsvFormatException(
        'Header has ${fields.length} columns; expected ${columns.length} '
        '(${columns.join(', ')}).',
        line: 1,
      );
    }
    for (var i = 0; i < columns.length; i++) {
      final actual = fields[i].value;
      if (actual != columns[i]) {
        throw WishCsvFormatException(
          "Header column ${i + 1} is '$actual'; expected '${columns[i]}'.",
          line: 1,
          column: columns[i],
        );
      }
    }
  }

  SerializableWish _decodeRow(_Record record, {required int line}) {
    final fields = record.fields;
    if (fields.length != columns.length) {
      throw WishCsvFormatException(
        'Row has ${fields.length} columns; expected ${columns.length}.',
        line: line,
      );
    }
    return SerializableWish(
      id: _required(fields[0], line: line, column: 'id'),
      title: _required(fields[1], line: line, column: 'title'),
      // Absent (bare empty) -> null; quoted empty -> ''.
      description: fields[2].isAbsent ? null : fields[2].value,
      categoryName: _required(fields[3], line: line, column: 'category'),
      priority: _decodePriority(fields[4], line: line),
      status: _decodeStatus(fields[5], line: line),
      progress: _decodeProgress(fields[6], line: line),
      createdAtUtc:
          _decodeTimestamp(fields[7], line: line, column: 'createdAtUtc'),
      updatedAtUtc:
          _decodeTimestamp(fields[8], line: line, column: 'updatedAtUtc'),
    );
  }

  String _required(_Field field, {required int line, required String column}) {
    if (field.isAbsent) {
      throw WishCsvFormatException(
        "Field '$column' is required but was empty.",
        line: line,
        column: column,
      );
    }
    return field.value;
  }

  Priority _decodePriority(_Field field, {required int line}) {
    final token = _required(field, line: line, column: 'priority');
    final value = _priorityByToken[token];
    if (value == null) {
      throw WishCsvFormatException(
        "Unknown priority token '$token'; "
        'expected one of ${_priorityByToken.keys.join(', ')}.',
        line: line,
        column: 'priority',
      );
    }
    return value;
  }

  LifecycleStatus _decodeStatus(_Field field, {required int line}) {
    final token = _required(field, line: line, column: 'status');
    final value = _statusByToken[token];
    if (value == null) {
      throw WishCsvFormatException(
        "Unknown status token '$token'; "
        'expected one of ${_statusByToken.keys.join(', ')}.',
        line: line,
        column: 'status',
      );
    }
    return value;
  }

  int _decodeProgress(_Field field, {required int line}) {
    final text = _required(field, line: line, column: 'progress');
    final value = int.tryParse(text);
    if (value == null) {
      throw WishCsvFormatException(
        "Progress '$text' is not an integer.",
        line: line,
        column: 'progress',
      );
    }
    return value;
  }

  DateTime _decodeTimestamp(
    _Field field, {
    required int line,
    required String column,
  }) {
    final text = _required(field, line: line, column: column);
    final DateTime parsed;
    try {
      parsed = DateTime.parse(text);
    } on FormatException {
      throw WishCsvFormatException(
        "Timestamp '$text' is not a valid ISO-8601 date-time.",
        line: line,
        column: column,
      );
    }
    return parsed.toUtc();
  }

  // --- RFC-4180 record parser ---
  //
  // Splits [source] into records of fields, honoring quoted fields that may
  // contain commas, CR, LF, and doubled quotes. Both CRLF and bare LF are
  // accepted as record separators between unquoted fields. A trailing record
  // separator does not produce a spurious empty record.

  List<_Record> _parseRecords(String source) {
    final records = <_Record>[];
    var fields = <_Field>[];
    final field = StringBuffer();
    var inQuotes = false;
    var fieldQuoted = false; // this field used quoting at least once
    var sawAnyField = false; // we have begun a (possibly empty) field/record
    var record = 1;

    void endField() {
      fields.add(
        fieldQuoted || field.isNotEmpty
            ? _Field.value(field.toString())
            : _Field.absent(),
      );
      field.clear();
      fieldQuoted = false;
    }

    void endRecord() {
      endField();
      records.add(_Record(fields));
      fields = <_Field>[];
      sawAnyField = false;
    }

    final chars = source.codeUnits;
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      if (inQuotes) {
        if (c == _quote) {
          final next = i + 1 < chars.length ? chars[i + 1] : -1;
          if (next == _quote) {
            field.writeCharCode(_quote);
            i++; // consume the doubled quote
          } else {
            inQuotes = false; // closing quote
          }
        } else {
          field.writeCharCode(c);
        }
        continue;
      }

      switch (c) {
        case _quote:
          inQuotes = true;
          fieldQuoted = true;
          sawAnyField = true;
          break;
        case _comma:
          sawAnyField = true;
          endField();
          break;
        case _cr:
          // Treat CRLF (and lone CR) as a single record separator.
          endRecord();
          record++;
          if (i + 1 < chars.length && chars[i + 1] == _lf) i++;
          break;
        case _lf:
          endRecord();
          record++;
          break;
        default:
          sawAnyField = true;
          field.writeCharCode(c);
      }
    }

    if (inQuotes) {
      throw WishCsvFormatException(
        'Unterminated quoted field.',
        line: record,
      );
    }

    // Flush a final record that was not followed by a trailing separator.
    if (sawAnyField || field.isNotEmpty || fieldQuoted || fields.isNotEmpty) {
      endRecord();
    }

    return records;
  }

  static const int _quote = 0x22; // "
  static const int _comma = 0x2C; // ,
  static const int _cr = 0x0D; // \r
  static const int _lf = 0x0A; // \n
}

/// A single parsed CSV field. [isAbsent] records whether the source field was
/// a bare empty string (no quoting) — the signal this codec uses to carry a
/// `null` description through a round trip.
final class _Field {
  const _Field._(this.value, this.isAbsent);

  factory _Field.value(String value) => _Field._(value, false);

  factory _Field.absent() => const _Field._('', true);

  final String value;
  final bool isAbsent;
}

/// A single parsed CSV record (one line of fields).
final class _Record {
  const _Record(this.fields);

  final List<_Field> fields;
}
