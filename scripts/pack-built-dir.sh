#!/usr/bin/env bash

# Script to create zip file from built directory
# Requires: source_path, dist_path, plugin_folder
# Uses sibling helper scripts from this script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Script to create zip file from built directory"
    echo "Usage: pack-built-dir.sh <source_path> <dist_path> <plugin_folder>"
    echo ""
    echo "Example:"
    echo "pack-built-dir.sh /path/to/plugin /path/to/dist /path/to/plugin-folder"
    echo ""
}

arg1="${1:-}"
arg2="${2:-}"
arg3="${3:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

if [ -z "${source_path:-}" ]; then
    source_path="$arg1"
fi

if [ -z "${dist_path:-}" ]; then
    dist_path="$arg2"
fi

if [ -z "${plugin_folder:-}" ]; then
    plugin_folder="$arg3"
fi

if [ -z "${source_path}" ] || [ -z "${dist_path}" ] || [ -z "${plugin_folder}" ]; then
    show_help
    exit 1
fi

# Get zip filename using plugin-zipfile.sh script
zip_filename=$("$SCRIPT_DIR/plugin-zipfile.sh" "$source_path")
zip_path="${dist_path}/${zip_filename}"

"$SCRIPT_DIR/echo-step.sh" "Removing old zip file, if exists"
if ! rm -f "${zip_path}"; then
    "$SCRIPT_DIR/echo-error.sh" "Failed to remove old zip file"
    exit 1
fi
if ! pushd "${dist_path}" >/dev/null 2>&1; then
    "$SCRIPT_DIR/echo-error.sh" "Failed to pushd"
    exit 2
fi

# Normalize permissions before zipping
"$SCRIPT_DIR/echo-step.sh" "Normalizing file permissions"
find ./${plugin_folder} -type f -exec chmod 644 {} \;
find ./${plugin_folder} -type d -exec chmod 755 {} \;

"$SCRIPT_DIR/echo-step.sh" "Creating the zip file on dist/${zip_filename} with normalized permissions"
if ! zip -qr "${zip_path}" ./${plugin_folder}; then
    "$SCRIPT_DIR/echo-error.sh" "Failed to create zip file"
    exit 3
fi

if ! popd >/dev/null 2>&1; then
    "$SCRIPT_DIR/echo-error.sh" "Failed to popd"
    exit 4
fi
