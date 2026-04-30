#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Script to display success messages with checkmark"
    echo "Usage: echo-success.sh <message>"
    echo ""
    echo "Example:"
    echo "echo-success.sh Successfully built the plugin."
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

if [ -z "$arg1" ]; then
    show_help
    exit 1
fi

echo "✅" " ${arg1}"
