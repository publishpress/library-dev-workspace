#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNING_CONTAINER=$(sh "$SCRIPT_DIR/terminal-detect-running-container.sh")

if [ -z "$RUNNING_CONTAINER" ]; then
    echo "Container is not running"
    exit 0
fi

docker stop $RUNNING_CONTAINER
