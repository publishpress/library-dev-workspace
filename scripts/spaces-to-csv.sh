#!/usr/bin/env bash
# Convert whitespace-separated tokens to a single comma-separated line (no spaces).
# Usage:
#   spaces-to-csv.sh "de_DE es_ES fi"
#   echo "de_DE es_ES fi" | spaces-to-csv.sh
#   spaces-to-csv.sh   # reads LANG_LOCALES from the environment if no stdin/args
set -euo pipefail

show_help() {
    echo "Script to convert whitespace-separated tokens to a single comma-separated line (no spaces)"
    echo "Usage: spaces-to-csv.sh [tokens]"
    echo ""
    echo "Example:"
    echo "spaces-to-csv.sh de_DE es_ES fi"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

input="${arg1}"

trimmed=$(echo "$input" | awk '{$1=$1};1')
if [ -z "$trimmed" ]; then
    printf ''
    exit 0
fi

read -ra parts <<< "$trimmed"
(IFS=','; printf '%s' "${parts[*]}")
