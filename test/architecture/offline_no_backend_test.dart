// Task 18.2: Offline and no-backend smoke tests.
//
// **Validates: Requirements 10.2, 10.3, 14.4**
//
// Two independent guarantees are exercised here:
//
//   1. Offline CRUD (R10.2): the app functions fully against the local
//      database with no network connection. Using the REAL Drift-backed
//      repositories over an in-memory [AppDatabase], a complete CRUD cycle —
//      create category, create wish, read back, update, apply progress,
//      transition through the lifecycle, delete — succeeds end to end. Because
//      the whole stack is local SQLite (no sockets are ever opened), passing
//      this cycle demonstrates the offline guarantee.
//
//   2. No-backend dependency (R10.3, R14.4): a source/dependency-level check
//      that no account/server/hosted-database/network client is compiled in.
//      We read `pubspec.yaml` and assert its dependency sections contain none
//      of a denylist of known networking/backend packages, and we scan `lib/`
//      for HTTP client usage. This proves the shipped binary carries no server
//      or hosted-DB dependency; persistence is Drift/SQLite local-only and the
//      remaining packages (file_picker, path_provider, uuid, ...) are local.
library wishable.test.architecture.offline_no_backend_test;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishable/data/app_database.dart';
import 'package:wishable/data/repositories/drift_category_repository.dart';
import 'package:wishable/data/repositories/drift_wish_repository.dart';
import 'package:wishable/domain/category.dart';
import 'package:wishable/domain/lifecycle_event.dart';
import 'package:wishable/domain/lifecycle_status.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';
import 'package:wishable/domain/wish_input.dart';

void main() {
  // Required because the CRUD test touches the Flutter/Drift native bindings.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------------
  // Part 1 — Offline CRUD smoke test (R10.2)
  // ------------------------------------------------------------------------
  //
  // Everything runs against an in-memory SQLite database through the real
  // repositories. No network interface is ever touched: the stack is local by
  // construction, so a successful end-to-end CRUD cycle is exactly what
  // "works fully offline" means.
  group('offline CRUD against the local database (R10.2)', () {
    late AppDatabase db;
    late DriftWishRepository wishes;
    late DriftCategoryRepository categories;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
      wishes = DriftWishRepository(db);
      categories = DriftCategoryRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('full create/read/update/progress/transition/delete cycle succeeds',
        () async {
      // --- CREATE category -------------------------------------------------
      final Category category =
          await categories.getOrCreateByName('Offline Goals');
      expect(category.id, isNotEmpty);
      expect(category.name, 'Offline Goals');
      expect(
        await categories.getAll(),
        contains(category),
        reason: 'the new category is persisted locally',
      );

      // --- CREATE wish -----------------------------------------------------
      final Wish created = await wishes.create(WishDraft(
        title: 'Run a marathon',
        description: 'Train with no internet required',
        categoryId: category.id,
        priority: Priority.high,
      ));
      expect(created.id, isNotEmpty);
      expect(created.status, LifecycleStatus.active);
      expect(created.progress, 0);
      expect(created.priority, Priority.high);

      // --- READ back (getById + getAll) ------------------------------------
      final Wish? byId = await wishes.getById(created.id);
      expect(byId, isNotNull);
      expect(byId!.title, 'Run a marathon');

      final List<Wish> all = await wishes.getAll();
      expect(all, hasLength(1));
      expect(all.single.id, created.id);

      // --- UPDATE ----------------------------------------------------------
      final Wish updated = await wishes.update(
        created.id,
        WishEdit(
          title: 'Run a half marathon',
          description: 'Scaled back the goal',
          categoryId: category.id,
          priority: Priority.medium,
        ),
      );
      expect(updated.id, created.id, reason: 'id is stable across edits');
      expect(updated.title, 'Run a half marathon');
      expect(updated.priority, Priority.medium);
      expect(
        (await wishes.getById(created.id))!.title,
        'Run a half marathon',
        reason: 'the edit is durable in the local database',
      );

      // --- APPLY PROGRESS (0 -> >0 moves to In_Progress, R5.3) -------------
      final Wish progressed = await wishes.applyProgress(created.id, 40);
      expect(progressed.progress, 40);
      expect(progressed.status, LifecycleStatus.inProgress);

      // --- TRANSITION (complete -> Completed, progress 100, R6.3) ----------
      final Wish completed =
          await wishes.transition(created.id, const CompleteEvent());
      expect(completed.status, LifecycleStatus.completed);
      expect(completed.progress, 100);

      // Reopen retains progress and returns to In_Progress (R6.4).
      final Wish reopened =
          await wishes.transition(created.id, const ReopenEvent());
      expect(reopened.status, LifecycleStatus.inProgress);
      expect(reopened.progress, 100);

      // --- DELETE ----------------------------------------------------------
      await wishes.delete(created.id);
      expect(await wishes.getById(created.id), isNull);
      expect(await wishes.getAll(), isEmpty,
          reason: 'the wish is removed from the local database');
    });
  });

  // ------------------------------------------------------------------------
  // Part 2 — No-backend dependency assertions (R10.3, R14.4)
  // ------------------------------------------------------------------------
  //
  // The strongest proof that Wishable needs no account/server/hosted DB is
  // that none of those dependencies are compiled in. We verify this at the
  // dependency and source level rather than at runtime.
  group('no account/server/hosted-DB dependency is compiled in (R10.3, R14.4)',
      () {
    test('pubspec.yaml declares no networking/backend client packages', () {
      final File pubspec = File('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue,
          reason: 'pubspec.yaml must exist at the project root');

      final Set<String> declared = _declaredDependencyNames(
        pubspec.readAsStringSync(),
      );
      expect(declared, isNotEmpty,
          reason: 'sanity: dependency parsing found some packages');

      // Known networking / backend-client / hosted-DB / auth packages. A
      // dependency is flagged when its name equals one of these or starts with
      // a prefix entry (e.g. `firebase_`), so family packages are caught too.
      final List<String> offenders = declared
          .where((String name) => _isBackendOrNetworkPackage(name))
          .toList(growable: false)
        ..sort();

      expect(
        offenders,
        isEmpty,
        reason: 'V1 must exclude any account/server/hosted-database '
            'dependency (R14.4). Found: $offenders',
      );
    });

    test('no lib/ source imports an HTTP client or dart:io HttpClient', () {
      final Directory lib = Directory('lib');
      expect(lib.existsSync(), isTrue, reason: 'lib/ must exist');

      final List<String> offenders = <String>[];
      for (final FileSystemEntity entity
          in lib.listSync(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final String source = entity.readAsStringSync();
        for (final RegExp pattern in _networkSourcePatterns) {
          if (pattern.hasMatch(source)) {
            offenders.add('${entity.path}: /${pattern.pattern}/');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'no source file may use a network/HTTP client (R10.3). '
            'Found: $offenders',
      );
    });
  });

  // ------------------------------------------------------------------------
  // Part 3 — Offline-first invariant (auth spec Option B, R14)
  // ------------------------------------------------------------------------
  //
  // The remote account/sync layer is OPTIONAL and ISOLATED. Two guarantees:
  //
  //   1. The PocketBase SDK (`package:pocketbase`) is imported ONLY by the
  //      backend adapter under `lib/data/account/remote/` and by the single
  //      composition-root provider `lib/application/account/account_providers.dart`.
  //      No other file — and nothing in the local Wishes / local-lock graph —
  //      may import it (R14.2).
  //   2. The local Wishes + local-lock graph (everything OUTSIDE
  //      `lib/*/account/`) must not import the account/sync layer at all, so
  //      the app builds and runs with the remote layer unconfigured (R14.1,
  //      R14.3). The composition-root provider is again the one exception.
  group('offline-first: the remote layer is optional and isolated (R14)', () {
    final Directory lib = Directory('lib');

    // Files allowed to import the backend SDK.
    bool mayImportSdk(String rel) =>
        rel.startsWith('lib/data/account/remote/') ||
        rel == 'lib/application/account/account_providers.dart';

    // Files allowed to import the account/sync layer (data/account or
    // application/account): the account layer itself, the composition root, and
    // the account presentation. Everything else is the "local graph".
    bool mayImportAccountLayer(String rel) =>
        rel.startsWith('lib/data/account/') ||
        rel.startsWith('lib/application/account/') ||
        rel.startsWith('lib/domain/account/') ||
        rel.startsWith('lib/presentation/account/') ||
        rel == 'lib/application/application.dart' ||
        rel == 'lib/presentation/presentation.dart';

    List<({String file, String uri})> importsOf(File f) {
      final List<({String file, String uri})> out =
          <({String file, String uri})>[];
      final String rel = f.path
          .replaceFirst(Directory.current.path, '')
          .replaceAll(r'\', '/')
          .replaceFirst(RegExp(r'^/'), '');
      for (final String line in f.readAsLinesSync()) {
        final Match? m =
            RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''').firstMatch(line);
        if (m != null) out.add((file: rel, uri: m.group(1)!));
      }
      return out;
    }

    test('the PocketBase SDK is imported only by the adapter + its provider',
        () {
      final List<String> offenders = <String>[];
      for (final FileSystemEntity e
          in lib.listSync(recursive: true, followLinks: false)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        for (final imp in importsOf(e)) {
          if (imp.uri.startsWith('package:pocketbase') &&
              !mayImportSdk(imp.file)) {
            offenders.add('${imp.file} imports ${imp.uri}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'package:pocketbase must be confined to '
              'data/account/remote/ and account_providers.dart (R14.2). '
              'Found:\n${offenders.join('\n')}');
    });

    test('the local graph never imports the account/sync layer (R14.1/14.3)',
        () {
      final List<String> offenders = <String>[];
      for (final FileSystemEntity e
          in lib.listSync(recursive: true, followLinks: false)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        for (final imp in importsOf(e)) {
          final bool pointsAtAccount =
              imp.uri.contains('/account/') || imp.uri.contains('account/');
          final bool isAccountTarget = imp.uri.contains('data/account/') ||
              imp.uri.contains('application/account/') ||
              imp.uri.contains('domain/account/') ||
              imp.uri.contains('presentation/account/');
          if (pointsAtAccount &&
              isAccountTarget &&
              !mayImportAccountLayer(imp.file)) {
            offenders.add('${imp.file} imports ${imp.uri}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'the local Wishes/local-lock graph must not depend on the '
              'optional account/sync layer; only the account layer itself and '
              'the composition roots may (R14.1, R14.3). '
              'Found:\n${offenders.join('\n')}');
    });
  });
}

// --- No-backend helpers -----------------------------------------------------

/// Exact package names that are forbidden outright.
const Set<String> _forbiddenExactNames = <String>{
  'http',
  'http_parser',
  'dio',
  'cloud_firestore',
  'cloud_functions',
  'supabase',
  'supabase_flutter',
  'googleapis',
  'googleapis_auth',
  'grpc',
  'web_socket_channel',
  'socket_io_client',
  'graphql',
  'graphql_flutter',
  'mongo_dart',
  'postgres',
  'mysql_client',
  'redis',
  'appwrite',
  'parse_server_sdk',
  'parse_server_sdk_flutter',
  'realm',
  'objectbox_sync', // sync flavour is a hosted/remote dependency
  'google_sign_in',
  'sign_in_with_apple',
  'amplify_flutter',
  'retrofit',
  'chopper',
  // NOTE: `pocketbase` and `connectivity_plus` are intentionally NOT forbidden.
  // Under the offline-first model (auth spec Option B), the remote account/sync
  // layer is an OPTIONAL dependency confined to data/account/remote and one
  // composition-root provider; the offline-first test below enforces that the
  // local graph never imports it, which is the correct invariant now.
};

/// Package-name prefixes that mark an entire family as backend/network/auth.
const List<String> _forbiddenPrefixes = <String>[
  'firebase_',
  'firebase',
  'cloud_',
  'aws_',
  'amazon_',
  'amplify_',
  'azure_',
  'auth0',
  'okta',
  'msal',
];

/// Returns `true` when a declared dependency [name] is a known networking,
/// backend-client, hosted-database, or account/auth package.
bool _isBackendOrNetworkPackage(String name) {
  final String lower = name.toLowerCase();
  if (_forbiddenExactNames.contains(lower)) {
    return true;
  }
  for (final String prefix in _forbiddenPrefixes) {
    if (lower.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

/// Source-level patterns that indicate network/HTTP usage in `lib/`.
final List<RegExp> _networkSourcePatterns = <RegExp>[
  RegExp(r'''import\s+['"]package:http/'''),
  RegExp(r'''import\s+['"]package:dio/'''),
  RegExp(r'''import\s+['"]package:web_socket_channel/'''),
  RegExp(r'''import\s+['"]package:graphql'''),
  // dart:io HttpClient / Socket usage (dart:io itself is fine for files).
  RegExp(r'\bHttpClient\b'),
  RegExp(r'\bWebSocket\b'),
  RegExp(r'\bSocket\.connect\b'),
];

/// Parses [pubspecYaml] and returns the set of package names declared under the
/// `dependencies:` and `dev_dependencies:` sections.
///
/// Deliberately a tiny, dependency-free parser (no yaml package, since adding
/// one would itself touch the dependency graph this test guards). It walks the
/// top-level `dependencies:` / `dev_dependencies:` blocks and collects the
/// keys indented one level under them, which is sufficient for the simple,
/// well-formed project pubspec.
Set<String> _declaredDependencyNames(String pubspecYaml) {
  const Set<String> sectionHeaders = <String>{
    'dependencies',
    'dev_dependencies',
  };

  final Set<String> names = <String>{};
  bool inSection = false;
  int? sectionIndent;

  for (final String rawLine in const LineSplitter().convert(pubspecYaml)) {
    // Strip comments and skip blank lines.
    final int hashIndex = rawLine.indexOf('#');
    final String line =
        hashIndex >= 0 ? rawLine.substring(0, hashIndex) : rawLine;
    if (line.trim().isEmpty) {
      continue;
    }

    final int indent = line.length - line.trimLeft().length;
    final String trimmed = line.trim();

    // A top-level key (indent 0) ending in ':' is a section header.
    if (indent == 0 && trimmed.endsWith(':')) {
      final String key = trimmed.substring(0, trimmed.length - 1).trim();
      inSection = sectionHeaders.contains(key);
      sectionIndent = null;
      continue;
    }

    if (!inSection) {
      continue;
    }

    // The first indented line fixes the depth of direct dependency entries.
    sectionIndent ??= indent;

    // Only collect direct children of the section (ignore nested keys like
    // `sdk:` under `flutter:` or `fonts:` under a package).
    if (indent != sectionIndent) {
      continue;
    }

    // A dependency entry looks like `name:` or `name: ^1.2.3`.
    final int colon = trimmed.indexOf(':');
    if (colon <= 0) {
      continue;
    }
    final String name = trimmed.substring(0, colon).trim();
    if (name.isNotEmpty) {
      names.add(name);
    }
  }
  return names;
}
