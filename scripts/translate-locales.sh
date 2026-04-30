#!/usr/bin/env bash
# Runs publishpress-translate for all languages in LANG_LOCALES (from .env).
# LANG_LOCALES should be set and env-bootstrap.sh sourced before running.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-bootstrap.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CSV="$("$SCRIPT_DIR/spaces-to-csv.sh" "${LANG_LOCALES}")"

exec "vendor/bin/publishpress-translate" --languages="$CSV"
