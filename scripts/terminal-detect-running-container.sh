#!/usr/bin/env bash

show_help() {
    echo "Script to detect the running container"
    echo "Usage: terminal-detect-running-container.sh"
    echo ""
    echo "Example:"
    echo "terminal-detect-running-container.sh"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

# Check for running containers matching CONTAINER_NAME but exclude test containers
docker ps --format "{{.Names}}" | grep -q "${CONTAINER_NAME}_term"

if [ $? -ne 0 ]; then
    echo ""
else
    # Get the container name, excluding test containers
    RUNNING_CONTAINER=$(docker ps --format "{{.Names}}" | grep "${CONTAINER_NAME}_term" | head -n 1)
    echo "$RUNNING_CONTAINER"
fi
