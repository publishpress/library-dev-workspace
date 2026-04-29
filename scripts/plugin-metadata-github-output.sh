#!/usr/bin/env bash

# Script to get plugin metadata from composer.json file and output it to the GitHub Actions output.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Show the usage information.
usage() {
    echo "Usage: plugin-metadata-github-output.sh"
}

# Output metadata fields to GitHub Actions output in a clear, expanded way.
PLUGIN_SLUG=$("$SCRIPT_DIR/plugin-slug.sh")
PLUGIN_FOLDER=$("$SCRIPT_DIR/plugin-folder.sh")
PLUGIN_NAME=$("$SCRIPT_DIR/plugin-name.sh")
PLUGIN_VERSION=$("$SCRIPT_DIR/plugin-version.sh")

echo "plugin-slug=${PLUGIN_SLUG}" >> "$GITHUB_OUTPUT"
echo "plugin-folder=${PLUGIN_FOLDER}" >> "$GITHUB_OUTPUT"
echo "plugin-name=${PLUGIN_NAME}" >> "$GITHUB_OUTPUT"
echo "plugin-version=${PLUGIN_VERSION}" >> "$GITHUB_OUTPUT"
