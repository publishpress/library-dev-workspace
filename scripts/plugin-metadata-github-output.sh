#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Script to get plugin metadata from composer.json file and output it to the GitHub Actions output."
    echo "Usage: plugin-metadata-github-output.sh"
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

if [ -z "${GITHUB_OUTPUT:-}" ]; then
    echo "GITHUB_OUTPUT is not set. Please run this script from a GitHub Actions workflow."
    exit 1
fi

for key in slug folder name version; do
    value="$("$SCRIPT_DIR/plugin-$key.sh")"
    echo "Plugin $key: $value"
    echo "plugin-$key=$value" >> "${GITHUB_OUTPUT}"
done
