#!/usr/bin/env bash
set -euo pipefail

show_help() {
    echo "Script to display step messages with arrow prefix"
    echo "Usage: echo-step.sh <message>"
    echo ""
    echo "Example:"
    echo "echo-step.sh Building the plugin..."
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

echo "▶ ${arg1}"
