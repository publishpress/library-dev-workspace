#!/usr/bin/env bash

# Script to display horizontal separator line

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Usage: echo-separator.sh"
    echo ""
    echo "Example:"
    echo "echo-separator.sh"
    echo ""
}

cols=$("$SCRIPT_DIR/terminal-cols.sh")

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

echo ""
"$SCRIPT_DIR/repeat.sh" "-" "${cols}"
echo ""
echo ""
