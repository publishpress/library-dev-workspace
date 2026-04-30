#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

show_help() {
    echo "Script to stop the dev-workspace"
    echo "Usage: stop.sh"
    echo ""
    echo "Example:"
    echo "stop.sh"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

cd "$DEV_WORKSPACE_DIR"

$SCRIPT_DIR/echo-step.sh "Stopping the dev-workspace"

sh "$SCRIPT_DIR/terminal-service-stop.sh"
