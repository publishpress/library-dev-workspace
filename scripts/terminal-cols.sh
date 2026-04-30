#!/usr/bin/env bash

# Script to display the number of columns in the terminal

show_help() {
    echo "Script to display the number of columns in the terminal"
    echo "Usage: terminal-cols.sh"
    echo ""
    echo "Example:"
    echo "terminal-cols.sh"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

cols=$(( ${#TERM} ? $(tput cols) : 80 ))

echo ${cols}
