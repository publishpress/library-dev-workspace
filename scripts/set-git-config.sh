#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

show_help() {
    echo "Script to set the Git config for a given directory"
    echo "Usage: set-git-config.sh <directory>"
    echo ""
    echo "Example:"
    echo "set-git-config.sh /path/to/plugin"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if the directory is already in the safe.directory list
if git config --global --get-all safe.directory | grep -Fxq "$1"; then
    "$SCRIPT_DIR/echo-step.sh" "Git config for $1 already exists, skipping"
else
    "$SCRIPT_DIR/echo-step.sh" "Setting Git config for $1"
    echo ""
    git config --global --add safe.directory "$1"
fi
