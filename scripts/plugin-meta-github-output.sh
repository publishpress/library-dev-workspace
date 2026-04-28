#!/usr/bin/env bash

# Script to get plugin metadata from composer.json file and output it to the GitHub Actions output.

# Show the usage information.
usage() {
    echo "Usage: plugin-meta-github-output.sh"
}

for field in plugin-slug plugin-folder plugin-name plugin-version; do
    value=$($field.sh)
    echo "${field//-/_}=${value}" >> "$GITHUB_OUTPUT"
done
