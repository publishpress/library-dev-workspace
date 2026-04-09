#!/usr/bin/env bash
# Run publishpress-translate with LANG_LOCALES from .env as a comma-separated list.
# Intended to be called via run.sh after env-init.sh has loaded and exported LANG_LOCALES.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CSV="$("$SCRIPT_DIR/spaces-to-csv.sh" "${LANG_LOCALES:-}")"

cd "$REPO_ROOT"
exec "$REPO_ROOT/vendor/bin/publishpress-translate" --languages="$CSV"
