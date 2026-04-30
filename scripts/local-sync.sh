#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Script to sync the plugin with the dev site using rsync and excluding files/directories listed on .rsync-filters-dev-sync"
    echo "Usage: local-sync.sh [--watch]"
    echo ""
    echo "Example:"
    echo "local-sync.sh"
    echo "local-sync.sh --watch"
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

# Load the .env file
source .env

SHOULD_WATCH="false"

if [[ "$arg1" == "--watch" ]]; then
  SHOULD_WATCH="true"
fi

separator1="$($SCRIPT_DIR/echo-separator.sh 1)"

$SCRIPT_DIR/echo-title.sh "Local Sync"

echo "Destination: ${LOCAL_SYNC_TARGET_DIR}"
echo "${separator1}"

# Function to perform the sync
sync_files() {
  echo "${separator1}"
  "$SCRIPT_DIR/echo-step.sh" "Syncing files..."
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Destination: ${LOCAL_SYNC_TARGET_DIR}"
  rsync -avz --exclude-from=.rsync-filters-dev-sync ./ ${LOCAL_SYNC_TARGET_DIR}
  "$SCRIPT_DIR/echo-success.sh" "Sync complete."
  echo "${separator1}"
}

# Sync the plugin with the dev site using rsync and excluding files/directories listed on .rsync-filters-dev-sync
if [[ $SHOULD_WATCH == "true" ]]; then
  # Detect OS
  OS="$(uname -s)"

  # Perform initial sync
  sync_files

  "$SCRIPT_DIR/echo-step.sh" "Watching for file changes..."

  if [[ "$OS" == "Linux" ]]; then
    # Check if inotifywait is installed
    if ! command -v inotifywait &> /dev/null; then
      "$SCRIPT_DIR/echo-error.sh" "Error: inotifywait is not installed. Install it with: sudo apt-get install inotify-tools"
      exit 1
    fi

    # Watch for file changes using inotifywait (Linux)
    # Exclude common directories that shouldn't trigger syncs
    while inotifywait -r -e modify,create,delete,move \
      --exclude '\.git' \
      --exclude 'node_modules' \
      --exclude 'vendor' \
      --exclude 'dist' \
      --exclude '\.rsync-filters-dev-sync' \
      . 2>/dev/null; do
      sync_files
    done

  elif [[ "$OS" == "Darwin" ]]; then
    # Check if fswatch is installed
    if ! command -v fswatch &> /dev/null; then
      "$SCRIPT_DIR/echo-error.sh" "Error: fswatch is not installed. Install it with: brew install fswatch"
      exit 1
    fi

    # Watch for file changes using fswatch (macOS)
    # Exclude common directories that shouldn't trigger syncs
    fswatch -o -r \
      --exclude '\.git' \
      --exclude 'node_modules' \
      --exclude 'vendor' \
      --exclude 'dist' \
      --exclude '\.rsync-filters-dev-sync' \
      . | while read f; do
      sync_files
    done

  else
    "$SCRIPT_DIR/echo-error.sh" "Error: Unsupported operating system: $OS"
    exit 1
  fi

else
  sync_files
fi
