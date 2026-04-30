#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Script to display horizontal separator line"
    echo "Usage: echo-separator.sh"
    echo ""
    echo "Example:"
    echo "echo-separator.sh"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

# Get the terminal width.
cols=$("$SCRIPT_DIR/terminal-cols.sh")

# Determine the separator character based on the number of arguments.
if [[ "$#" -eq 0 ]]; then
    separator_char="─"
elif [[ "${1}" =~ ^[0-9]+$ ]]; then
    if [[ "${1}" == "1" ]]; then
        separator_char="─"
    elif [[ "${1}" == "2" ]]; then
        separator_char="═"
    else
        separator_char="─"
    fi
else
    separator_char="${1}"
fi

echo ""
"$SCRIPT_DIR/repeat.sh" "$separator_char" "${cols}"
echo ""
echo ""
