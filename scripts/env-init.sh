#!/usr/bin/env bash

DEV_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_WORKSPACE_DIR="$(cd "$DEV_SCRIPTS_DIR/.." && pwd)"
REPO_ROOT="$(cd "$DEV_WORKSPACE_DIR/../../.." && pwd)"

# Subprocesses (e.g. pack.sh spawned from run.sh) must inherit these paths.
export DEV_SCRIPTS_DIR DEV_WORKSPACE_DIR REPO_ROOT

if [[ ! -f "$REPO_ROOT/.env" ]]; then
    echo "Error: .env file not found. Run 'cp .env.example .env' to create it."
    exit 1
fi

set -a
source "$REPO_ROOT/.env"
set +a

if [[ "$CACHE_PATH" != /* ]]; then
    CACHE_PATH="$REPO_ROOT/$CACHE_PATH"
fi
