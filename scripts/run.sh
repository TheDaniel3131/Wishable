#!/usr/bin/env bash
# Wishable run/build helper (macOS / Linux / CI).
#
# Reads KEY=VALUE pairs from .env (ignoring blanks and # comments) and forwards
# each non-empty value to Flutter as a --dart-define, then runs the given
# Flutter command. This bridges a runtime-style .env to Flutter's compile-time
# String.fromEnvironment.
#
# Usage:
#   ./scripts/run.sh                  # defaults to: run -d chrome
#   ./scripts/run.sh run -d macos
#   ./scripts/run.sh build web
#   ./scripts/run.sh build apk --release
#
# Any arguments replace the default Flutter subcommand/flags; the --dart-define
# values from .env are always appended.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"

DEFINES=()
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}" # ltrim
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    # trim surrounding whitespace from key/value
    key="$(echo -n "$key" | xargs)"
    value="$(echo -n "$value" | xargs)"
    if [[ -n "$value" ]]; then
      DEFINES+=("--dart-define=$key=$value")
    fi
  done < "$ENV_FILE"
else
  echo "No .env found (copy .env.example to .env). Running with defaults." >&2
fi

if [[ $# -eq 0 ]]; then
  set -- run -d chrome
fi

echo "> flutter $* ${DEFINES[*]:-}"
exec flutter "$@" "${DEFINES[@]}"
