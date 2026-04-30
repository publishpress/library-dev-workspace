#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Script to repeat a string n times"
    echo "Usage: repeat.sh <string> <times>"
    echo ""
    echo "Example:"
    echo "repeat.sh Hello 3"
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

arg2="${2:-1}" # Use the second argument or set a default value of 1

string="$arg1"
times="${arg2}"

for ((c = 1; c <= times; c++)); do
    echo -n "$string"
done
