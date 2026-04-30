#!/usr/bin/env bash
# Runs publishpress-translate for all languages in LANG_LOCALES (from .env).
# LANG_LOCALES should be set and env-bootstrap.sh sourced before running.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

CSV="$("$SCRIPT_DIR/spaces-to-csv.sh" "${LANG_LOCALES}")"

if exec "$REPO_ROOT/vendor/bin/publishpress-translate" --languages="$CSV"; then
    echo ""
    $SCRIPT_DIR/echo-separator.sh
    $SCRIPT_DIR/echo-success.sh "Translation locales completed successfully"
else
    echo ""
    $SCRIPT_DIR/echo-separator.sh
    $SCRIPT_DIR/echo-error.sh "Translation locales failed"
    exit 1
fi
