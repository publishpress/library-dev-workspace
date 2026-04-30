#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Script to display error messages with X mark"
    echo "Usage: echo-error.sh <message>"
    echo ""
    echo "Example:"
    echo "echo-error.sh An error occurred while building the plugin."
    echo ""
}

arg1="${1:-}"

if [ -z "$arg1" ]; then
    show_help
    exit 1
fi

if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

echo "❌" " ${arg1}"
