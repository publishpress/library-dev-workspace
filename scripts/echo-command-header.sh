#!/usr/bin/env bash

# Script to display command header with rocket emoji
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Usage: echo-command-header.sh <command>"
    echo ""
    echo "Example:"
    echo "echo-command-header.sh Building the plugin..."
    echo ""
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

if [ -z "$1" ]; then
    show_help
    exit 1
fi

"$SCRIPT_DIR/echo-separator.sh"
echo "🚀" " ${1}"
echo ""
