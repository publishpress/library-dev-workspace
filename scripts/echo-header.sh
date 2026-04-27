#!/usr/bin/env bash

# Script to display the formatted plugin builder header
# Requires: echo-box-line.sh, workspace-version.sh, plugin-name.sh, plugin-version.sh, plugin-slug.sh, plugin-folder.sh in PATH

show_help() {
    echo "Usage: echo-header.sh"
    echo ""
    echo "Example:"
    echo "echo-header.sh"
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
echo "     - Name   : $(plugin-name.sh)"
echo "     - Slug   : $(plugin-slug.sh)"
echo "     - Folder : $(plugin-folder.sh)"
echo "     - Version: $(plugin-version.sh)"
echo ""
echo-separator.sh
echo ""
