/// PocketBase client configuration + construction (auth spec, Option B).
///
/// Centralizes how the `PocketBase` SDK client is built and configured so both
/// the auth and sync adapters share one client and one base-URL source. This
/// and its siblings under `remote/` are the ONLY files permitted to import the
/// `pocketbase` SDK; nothing above the data layer references it (offline-first
/// test, R14.2).
///
/// The base URL comes from configuration (e.g. a build-time `--dart-define` or
/// a settings value). When it is empty/unset, Option B is considered
/// unconfigured: the app stays signed-out and offline-first, and no client is
/// created (R14.1, R14.3).
library wishable.data.account.remote.pocketbase_client;

import 'package:pocketbase/pocketbase.dart';

/// Resolves the configured PocketBase base URL.
///
/// Reads the compile-time `WISHABLE_PB_URL` define. Empty means "Option B not
/// configured" — callers must treat the remote layer as absent.
const String kPocketBaseUrl =
    String.fromEnvironment('WISHABLE_PB_URL', defaultValue: '');

/// Whether a PocketBase backend is configured for this build/run.
bool get isPocketBaseConfigured => kPocketBaseUrl.isNotEmpty;

/// Builds a [PocketBase] client over [baseUrl]. The caller owns the instance
/// and shares it between the auth and sync adapters so they use one session.
PocketBase createPocketBaseClient(String baseUrl) => PocketBase(baseUrl);
