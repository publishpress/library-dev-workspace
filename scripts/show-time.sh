#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Script to display elapsed runtime"
    echo "Usage: show-time.sh"
    echo ""
    echo "Example:"
    echo "show-time.sh"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

if [ -z "$arg1" ]; then
    show_help
    exit 1
fi

start_time=${arg1}

if [ "${HIDE_HEADER}" != "1" ]; then
    end_time=$(date +%s)
    runtime_seconds=$((end_time - start_time))

    if [ "$runtime_seconds" -lt 1 ]; then
        echo "Runtime: less than 1 second"
    elif [ "$runtime_seconds" = 1 ]; then
        echo "Runtime: $runtime_seconds second"
    else
        echo "Runtime: $runtime_seconds seconds"
    fi
fi
