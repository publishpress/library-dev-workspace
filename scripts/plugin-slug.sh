#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SOURCE_PATH="${GITHUB_WORKSPACE:-/project}"
SOURCE_PATH="${1:-$DEFAULT_SOURCE_PATH}"
COMPOSER_FILE="${SOURCE_PATH}/composer.json"

show_help() {
    echo "Script to get the plugin slug from composer.json file."
    echo "Usage: plugin-slug.sh [source_path]"
    echo "source_path: Path to the plugin source code. Default: Current directory."
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

if [ ! -f "$COMPOSER_FILE" ]; then
    "$SCRIPT_DIR/echo-error.sh" "Error: composer.json not found in ${SOURCE_PATH}"
    exit 2
fi

"$SCRIPT_DIR/parse-json.sh" "$COMPOSER_FILE" "extra.plugin-slug"
