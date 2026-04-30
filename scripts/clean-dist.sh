#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Script to remove temporary build directories"
    echo "Usage: clean-dist.sh [tmp_build_dir]"
    echo ""
    echo "Removes the temporary build directory and its temporary files."
    echo "If tmp_build_dir is not provided, it will use the value of the tmp_build_dir variable."
    echo "If tmp_build_dir is set, it will remove the folder and its temporary files."
    echo "If tmp_build_dir is not set, it will exit with an error."
    echo ""
    echo "Example:"
    echo "clean-dist.sh /tmp/build-dir"
    echo "clean-dist.sh"
    echo "clean-dist.sh /tmp/build-dir"
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

if [ -z "${tmp_build_dir:-}" ]; then
    tmp_build_dir="$arg1"
fi

if [ -z "${tmp_build_dir:-}" ]; then
    "$SCRIPT_DIR/echo-error.sh" "Error: tmp_build_dir variable is empty or not set."
    show_help
    exit 1
fi

"$SCRIPT_DIR/echo-step.sh" "Removing the folder ${tmp_build_dir} and its temporary files"
if rm -rf "${tmp_build_dir}" "${tmp_build_dir}-tmp"; then
    :
else
    "$SCRIPT_DIR/echo-error.sh" "Failed to remove '${tmp_build_dir}' or '${tmp_build_dir}-tmp'"
    exit 1
fi
