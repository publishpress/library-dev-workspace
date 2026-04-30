#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set the SOURCE_PATH variable to the current directory or use the passed argument.
DEFAULT_SOURCE_PATH="${GITHUB_WORKSPACE:-/project}"
SOURCE_PATH="${1:-$DEFAULT_SOURCE_PATH}"

# Show the usage information.
show_help() {
    echo "Script to get the plugin folder from composer.json file."
    echo "Usage: plugin-folder.sh [source_path]"
    echo ""
    echo "source_path: The path to the source code of the plugin."
    echo "             Default: The current directory."
}

# Check if the usage information should be displayed.
arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if the composer.json file exists in the source path.
if [ ! -f "${SOURCE_PATH}/composer.json" ]; then
    "$SCRIPT_DIR/echo-error.sh" "The composer.json file does not exist in the source path."
    echo ""
    echo "Source path: ${SOURCE_PATH}"
    exit 2
fi

# Get the plugin name from the composer.json file.
"$SCRIPT_DIR/parse-json.sh" "${SOURCE_PATH}/composer.json" "extra.plugin-folder"
