#!/usr/bin/env bash

# Script to display the formatted plugin builder header

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Usage: echo-builder-header.sh"
    echo ""
    echo "Example:"
    echo "echo-builder-header.sh"
    echo ""
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

echo ""
echo "======================================================================="
echo "                        PUBLISHPRESS BUILDER"
echo "======================================================================="
echo ""

if [ "${DEV_WORKSPACE_VERSION}" != "1" ]; then
    echo "   Dev-workspace version: ${DEV_WORKSPACE_VERSION}"
fi

echo ""
echo "   Plugin Information:"
echo "     - Name   : $("$SCRIPT_DIR/plugin-name.sh")"
echo "     - Slug   : $("$SCRIPT_DIR/plugin-slug.sh")"
echo "     - Folder : $("$SCRIPT_DIR/plugin-folder.sh")"
echo "     - Version: $("$SCRIPT_DIR/plugin-version.sh")"
echo ""
"$SCRIPT_DIR/echo-separator.sh"
echo ""
