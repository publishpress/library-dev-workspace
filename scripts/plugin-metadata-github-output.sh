#!/usr/bin/env bash

# Script to get plugin metadata from composer.json file and output it to the GitHub Actions output.

# Show the usage information.
usage() {
    echo "Usage: plugin-meta-github-output.sh"
}

# Output metadata fields to GitHub Actions output in a clear, expanded way.
plugin_slug=$(plugin-slug.sh)
plugin_folder=$(plugin-folder.sh)
plugin_name=$(plugin-name.sh)
plugin_version=$(plugin-version.sh)

echo "plugin_slug=${plugin_slug}" >> "$GITHUB_OUTPUT"
echo "plugin_folder=${plugin_folder}" >> "$GITHUB_OUTPUT"
echo "plugin_name=${plugin_name}" >> "$GITHUB_OUTPUT"
echo "plugin_version=${plugin_version}" >> "$GITHUB_OUTPUT"
