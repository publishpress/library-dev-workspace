#!/usr/bin/env bash

# Script to set the Git config for a given directory
# Uses sibling helper scripts from this script directory
# Requires: git
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if the directory is already in the safe.directory list
if git config --global --get-all safe.directory | grep -Fxq "$1"; then
    "$SCRIPT_DIR/echo-step.sh" "Git config for $1 already exists, skipping"
else
    "$SCRIPT_DIR/echo-step.sh" "Setting Git config for $1"
    echo ""
    git config --global --add safe.directory "$1"
fi
