#!/usr/bin/env bash
# Convert whitespace-separated tokens to a single comma-separated line (no spaces).
# Usage:
#   spaces-to-csv.sh "de_DE es_ES fi"
#   echo "de_DE es_ES fi" | spaces-to-csv.sh
#   spaces-to-csv.sh   # reads LANG_LOCALES from the environment if no stdin/args
set -euo pipefail

input=""
if [ $# -gt 0 ]; then
    input="$*"
elif [ -n "${LANG_LOCALES:-}" ]; then
    input="${LANG_LOCALES}"
elif ! [ -t 0 ]; then
    input=$(cat)
else
    input=""
fi

trimmed=$(echo "$input" | awk '{$1=$1};1')
if [ -z "$trimmed" ]; then
    printf ''
    exit 0
fi

read -ra parts <<< "$trimmed"
(IFS=','; printf '%s' "${parts[*]}")
