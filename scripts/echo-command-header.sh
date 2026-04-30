#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Script to display command header with rocket emoji"
    echo "Usage: echo-command-header.sh <command>"
    echo ""
    echo "Example:"
    echo "echo-command-header.sh Building the plugin..."
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

"$SCRIPT_DIR/echo-separator.sh"
echo ""
echo "🚀" " ${arg1}"
echo ""
