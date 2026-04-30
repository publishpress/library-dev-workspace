#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Script to display the formatted plugin builder header"
    echo "Usage: echo-builder-header.sh"
    echo ""
    echo "Example:"
    echo "echo-builder-header.sh"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

separator1="$($SCRIPT_DIR/echo-separator.sh 1)"

$SCRIPT_DIR/echo-title.sh "PublishPress Builder"

if [ "${DEV_WORKSPACE_VERSION}" != "1" ]; then
    echo "Dev-workspace Version: ${DEV_WORKSPACE_VERSION}"
    echo "${separator1}"
fi

marker="●"
indent="    "
echo "Plugin Information:"
echo ""
echo "${indent}$marker Name   : $("$SCRIPT_DIR/plugin-name.sh")"
echo "${indent}$marker Slug   : $("$SCRIPT_DIR/plugin-slug.sh")"
echo "${indent}$marker Folder : $("$SCRIPT_DIR/plugin-folder.sh")"
echo "${indent}$marker Version: $("$SCRIPT_DIR/plugin-version.sh")"
echo ""
echo "${separator1}"
