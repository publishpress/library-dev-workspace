#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Show the usage information.
show_help() {
    echo "Script to get plugin metadata from composer.json file and output it to the GitHub Actions output."
    echo "Usage: plugin-metadata-github-output.sh"
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

# Output metadata fields to GitHub Actions output in a clear, expanded way.
PLUGIN_SLUG=$("$SCRIPT_DIR/plugin-slug.sh")
PLUGIN_FOLDER=$("$SCRIPT_DIR/plugin-folder.sh")
PLUGIN_NAME=$("$SCRIPT_DIR/plugin-name.sh")
PLUGIN_VERSION=$("$SCRIPT_DIR/plugin-version.sh")

echo "plugin-slug=${PLUGIN_SLUG}" >> "$GITHUB_OUTPUT"
echo "plugin-folder=${PLUGIN_FOLDER}" >> "$GITHUB_OUTPUT"
echo "plugin-name=${PLUGIN_NAME}" >> "$GITHUB_OUTPUT"
echo "plugin-version=${PLUGIN_VERSION}" >> "$GITHUB_OUTPUT"
