#!/usr/bin/env bash

# Script to display the formatted title

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Script to display the formatted title"
    echo "Usage: echo-title.sh <title>"
    echo ""
    echo "Example:"
    echo "echo-title.sh PublishPress Builder"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

if [ -z "$1" ]; then
    show_help
    exit 1
fi

title="${1}"
separator1="$($SCRIPT_DIR/echo-separator.sh 1)"
separator2="$($SCRIPT_DIR/echo-separator.sh 2)"

echo "${separator2}"
echo ""
echo "${title}"
echo "${separator2}"
