#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SOURCE_PATH="${GITHUB_WORKSPACE:-/project}"
SOURCE_PATH="${1:-$DEFAULT_SOURCE_PATH}"
PLUGIN_SLUG=$("$SCRIPT_DIR/plugin-slug.sh" "$SOURCE_PATH")
PLUGIN_FILE_PATH="${SOURCE_PATH}/${PLUGIN_SLUG}.php"

show_help() {
    echo "Script to get the plugin version."
    echo "Usage: plugin-version.sh [source_path]"
    echo "source_path: Path to the plugin source code. Default: Current directory."
}

# Display usage if help is requested
arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if the main plugin file exists
if [ ! -f "${PLUGIN_FILE_PATH}" ]; then
    "$SCRIPT_DIR/echo-error.sh" "Error: Main plugin file not found in ${SOURCE_PATH}"
    exit 2
fi

# Extract and output the plugin version
grep "* Version:" "${PLUGIN_FILE_PATH}" | sed -E 's/[^0-9.]*([0-9.]+(-[a-zA-Z]+\.[0-9]+)?).*/\1/'
