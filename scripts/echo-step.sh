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

if [ -z "$1" ]; then
    show_help
    exit 1
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

echo "▶ ${1}"
