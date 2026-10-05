// Feature: wishable — Architecture test for task 18.1.
//
// **Data-access boundary architecture test**
// **Validates: Requirements 14.3**
//
// R14.3 requires that the Presentation and Application layers depend on the
// data layer ONLY through the Drift-free abstractions (the repository /
// backup-service interfaces exposed by the data barrel), never on Drift or on
// the concrete Drift-backed implementations. This guarantees the UI and
// controllers remain ignorant of the persistence technology.
//
// This is a SOURCE-LEVEL test, not a widget test. It uses `dart:io` to read
// every `.dart` file under `lib/presentation/` and `lib/application/`
// (recursively), parses each `import` directive, and asserts that NONE of them
// name a forbidden target. It compiles no app code, so it stays fast and does
// not depend on the Flutter engine.
//
// Forbidden import targets (detected by matching the import's URI):
//   - `package:drift/...`              — the Drift runtime itself
//   - `package:drift_flutter/...`      — the Drift Flutter helper
//   - `package:sqlite3...`             — the SQLite engine binding
//   - `drift/native.dart`, `drift/wasm.dart` — Drift platform backends
//   - the generated database: `app_database.dart` / `app_database.g.dart`
//     (relative or `package:wishable/data/...`)
//   - the schema: `tables.dart`
//   - the concrete Drift-backed classes: any `drift_*.dart` file under
//     `data/repositories/` (e.g. `drift_wish_repository.dart`)
//
// Allowed (so the correctly-layered current codebase passes):
//   - `lib/application/providers.dart` — the composition root — MAY import the
//     data barrel `../data/data.dart` to construct providers, because that is
//     where the concrete `Drift*` types are wired. It still MUST NOT import
//     `package:drift` or any `drift/*.dart` directly.
//   - any other `data/...` import that names only a Drift-free interface/helper
//     (`wish_repository.dart`, `category_repository.dart`,
//     `settings_repository.dart`, `backup_service.dart`, `priority_sort.dart`,
//     or the `repositories.dart` barrel).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A forbidden import found while scanning a layer file.
class _Violation {
  _Violation(this.file, this.importUri, this.reason);

  /// Path relative to the repository root, using `/` separators.
  final String file;

  /// The raw URI string from the offending `import` directive.
  final String importUri;

  /// Human-readable explanation of why this import breaks R14.3.
  final String reason;

  @override
  String toString() => '  $file\n      imports "$importUri"\n      -> $reason';
}

/// Matches a single-line Dart import directive and captures its URI, e.g.
/// `import 'package:drift/drift.dart';` -> `package:drift/drift.dart`.
final RegExp _importDirective = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''');

/// Returns the reason an [importUri] is forbidden for a file in the
/// presentation/application layers, or `null` if the import is allowed.
///
/// [isCompositionRoot] relaxes the rule to permit the data barrel
/// (`data/data.dart`) for `application/providers.dart`, the single seam where
/// the concrete Drift types are wired into providers. Even there, direct Drift
/// package imports remain forbidden.
String? _forbiddenReason(String importUri, {required bool isCompositionRoot}) {
  // 1) Drift runtime and platform backends, SQLite engine — never allowed.
  if (importUri.startsWith('package:drift/') ||
      importUri == 'package:drift' ||
      importUri.startsWith('package:drift_flutter/') ||
      importUri.startsWith('package:sqlite3')) {
    return 'direct dependency on Drift/SQLite is forbidden above the data '
        'layer (R14.3)';
  }
  if (importUri.endsWith('drift/native.dart') ||
      importUri.endsWith('drift/wasm.dart')) {
    return 'Drift platform backend must not be referenced above the data '
        'layer (R14.3)';
  }

  // Normalise the trailing filename segment for the relative/package checks.
  final String leaf = importUri.split('/').last;

  // 2) The generated Drift database. Allowed only via the data barrel at the
  //    composition root; a direct import of the database file is never allowed.
  if (leaf == 'app_database.dart' || leaf == 'app_database.g.dart') {
    return 'the generated Drift database must not be imported directly '
        '(use the repository interfaces) (R14.3)';
  }

  // 3) The Drift table definitions.
  if (leaf == 'tables.dart') {
    return 'the Drift table schema must not be imported above the data layer '
        '(R14.3)';
  }

  // 4) Concrete Drift-backed implementation classes (drift_*.dart) under the
  //    data layer. Consumers must use the abstract interfaces instead.
  final bool pointsAtData =
      importUri.contains('/data/') || importUri.startsWith('../data/');
  if (pointsAtData && leaf.startsWith('drift_') && leaf.endsWith('.dart')) {
    return 'a concrete Drift repository/service implementation must not be '
        'imported directly (use its interface) (R14.3)';
  }

  // 5) The data barrel `data.dart` re-exports the concrete Drift types, so a
  //    presentation/application file importing it would transitively see Drift.
  //    This is permitted ONLY at the composition root (providers.dart).
  if (leaf == 'data.dart' &&
      (pointsAtData || importUri.endsWith('/data.dart'))) {
    if (isCompositionRoot) return null;
    return 'the data barrel exposes concrete Drift types and may only be '
        'imported by the composition root (application/providers.dart) '
        '(R14.3)';
  }

  return null;
}

/// Recursively collects every `.dart` file under [dir].
List<File> _dartFilesUnder(Directory dir) {
  if (!dir.existsSync()) return <File>[];
  return dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList(growable: false);
}

void main() {
  group('data-access boundary (R14.3)', () {
    // Resolve paths relative to the package root (test runner CWD).
    final Directory root = Directory.current;
    final Directory presentationDir =
        Directory('${root.path}/lib/presentation');
    final Directory applicationDir = Directory('${root.path}/lib/application');

    test('presentation and application layers never depend on Drift', () {
      final List<File> files = <File>[
        ..._dartFilesUnder(presentationDir),
        ..._dartFilesUnder(applicationDir),
      ];

      // Guard against silently scanning nothing (e.g. wrong CWD / moved dirs):
      // if the layers vanished, the test would vacuously pass and stop
      // protecting the boundary.
      expect(
        files,
        isNotEmpty,
        reason: 'expected to find .dart files under lib/presentation and '
            'lib/application to scan; found none',
      );

      final List<_Violation> violations = <_Violation>[];

      for (final File file in files) {
        final String rel = file.path
            .replaceFirst(root.path, '')
            .replaceAll(r'\', '/')
            .replaceFirst(RegExp(r'^/'), '');

        // Only application/providers.dart is the composition root.
        final bool isCompositionRoot = rel == 'lib/application/providers.dart';

        final List<String> lines = file.readAsLinesSync();
        for (final String line in lines) {
          final Match? m = _importDirective.firstMatch(line);
          if (m == null) continue;
          final String uri = m.group(1)!;
          final String? reason =
              _forbiddenReason(uri, isCompositionRoot: isCompositionRoot);
          if (reason != null) {
            violations.add(_Violation(rel, uri, reason));
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'The presentation/application layers must reach the data layer '
            'only through the Drift-free interfaces (R14.3). '
            'Found ${violations.length} forbidden import(s):\n'
            '${violations.join('\n')}',
      );
    });
  });
}
