#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Set the SOURCE_PATH variable to the current directory or use the passed argument.
DEFAULT_SOURCE_PATH="${GITHUB_WORKSPACE:-/project}"
SOURCE_PATH="${1:-$DEFAULT_SOURCE_PATH}"

# Show the usage information.
show_help() {
    echo "Script to get the plugin ZIP file name in the dist dir."
    echo "Usage: plugin-zipfile.sh [source_path]"
    echo "Options:"
    echo "  -h, --help        Display this help message."
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

# Output the ZIP file name
echo "$("$SCRIPT_DIR/plugin-name.sh" "$SOURCE_PATH")-$("$SCRIPT_DIR/plugin-version.sh" "$SOURCE_PATH").zip"
