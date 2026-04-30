#!/bin/bash

# PublishPress Hub Statistics Plugin Remote Sync Script
# Watches for changes in the plugin directory and syncs to remote WordPress site via SSH

set -a
source .env
set +a

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

# Configuration
SOURCE_DIR=$REMOTE_SYNC_SOURCE_DIR
REMOTE_HOST=$REMOTE_SYNC_REMOTE_HOST
REMOTE_PORT=$REMOTE_SYNC_REMOTE_PORT
REMOTE_TARGET_DIR=$REMOTE_SYNC_REMOTE_TARGET_DIR
SSH_KEY_PATH=$REMOTE_SYNC_SSH_KEY_PATH
EXCLUDE_FILE=".rsync-filters-sync"

# SSH Configuration
SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o ServerAliveInterval=600 -o ServerAliveCountMax=5 -o LogLevel=ERROR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to sync files
sync_files() {
    $SCRIPT_DIR/echo-step.sh "Syncing files to remote..."

    # Create target directory on remote if it doesn't exist
    ssh -i "$SSH_KEY_PATH" -p "$REMOTE_PORT" $SSH_OPTIONS "$REMOTE_HOST" "mkdir -p '$REMOTE_TARGET_DIR'"

    # Sync files using rsync over SSH
    if rsync -av --delete \
        -e "ssh -i $SSH_KEY_PATH -p $REMOTE_PORT $SSH_OPTIONS" \
        --exclude-from="$SOURCE_DIR/$EXCLUDE_FILE" \
        "$SOURCE_DIR/" "$REMOTE_HOST:$REMOTE_TARGET_DIR/"; then

        $SCRIPT_DIR/echo-success.sh "Remote sync completed successfully"
    else
        $SCRIPT_DIR/echo-error.sh "Remote sync failed"
    fi
}

# Detect OS and set file watching tool
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        FILE_WATCHER="fswatch"
    else
        FILE_WATCHER="inotifywait"
    fi
}

# Function to check if file watching tool is available
check_file_watcher() {
    detect_os

    if ! command -v "$FILE_WATCHER" &> /dev/null; then
        $SCRIPT_DIR/echo-error.sh "Error: $FILE_WATCHER is not installed."
        if [[ "$FILE_WATCHER" == "fswatch" ]]; then
            $SCRIPT_DIR/echo-error.sh "Please install it with: brew install fswatch"
        else
            $SCRIPT_DIR/echo-error.sh "Please install it with: sudo apt-get install inotify-tools"
        fi
        exit 2
    fi

    $SCRIPT_DIR/echo-success.sh "Using file watcher: $FILE_WATCHER"
}

# Function to test SSH connection
test_ssh_connection() {
    $SCRIPT_DIR/echo-step.sh "Testing SSH connection to $REMOTE_HOST..."
    if ssh -i "$SSH_KEY_PATH" -p "$REMOTE_PORT" $SSH_OPTIONS "$REMOTE_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
        $SCRIPT_DIR/echo-success.sh "SSH connection test successful"
        return 0
    else
        $SCRIPT_DIR/echo-error.sh "SSH connection test failed"
        echo ""
        echo "Please check your SSH configuration:"
        echo "  - SSH key path: $SSH_KEY_PATH"
        echo "  - Remote host: $REMOTE_HOST"
        echo "  - Remote port: $REMOTE_PORT"
        echo "  - Make sure your SSH key is added to the remote server"
        exit 3
    fi
}

# Function to show usage
show_help() {
    echo "Script to sync the plugin with the remote site using rsync and excluding files/directories listed on .rsync-filters-sync"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -o, --once     Sync once and exit"
    echo "  -w, --watch    Watch for changes and sync continuously (default)"
    echo "  -t, --test     Test SSH connection and exit"
    echo ""
    echo "Examples:"
    echo "  $0              # Watch for changes and sync continuously"
    echo "  $0 --once       # Sync once and exit"
    echo "  $0 --watch      # Watch for changes and sync continuously"
    echo "  $0 --test       # Test SSH connection"
    echo ""
    echo "Configuration:"
    echo "  Edit the variables at the top of this script to configure:"
    echo "  - SOURCE_DIR: Local source directory"
    echo "  - REMOTE_HOST: Remote SSH host (user@hostname)"
    echo "  - REMOTE_PORT: SSH port (default: 22)"
    echo "  - REMOTE_TARGET_DIR: Remote target directory"
    echo "  - SSH_KEY_PATH: Path to SSH private key"
}

# Parse command line arguments
WATCH_MODE=true
TEST_SSH=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -o|--once)
            WATCH_MODE=false
            shift
            ;;
        -w|--watch)
            WATCH_MODE=true
            shift
            ;;
        -t|--test)
            TEST_SSH=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 4
            ;;
    esac
done

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    $SCRIPT_DIR/echo-error.sh "Error: Source directory does not exist: $SOURCE_DIR"
    exit 5
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    $SCRIPT_DIR/echo-error.sh "Error: SSH key not found: $SSH_KEY_PATH"
    echo ""
    echo "Please update the SSH_KEY_PATH variable"
    exit 6
fi

# Test SSH connection if requested
if [ "$TEST_SSH" = true ]; then
    test_ssh_connection
    exit $?
fi

# Check if file watcher is available
check_file_watcher

echo -e "${BLUE}PublishPress Hub Statistics Plugin Remote Sync Script${NC}"
echo -e "${BLUE}Source: $SOURCE_DIR${NC}"
echo -e "${BLUE}Remote: $REMOTE_HOST:$REMOTE_TARGET_DIR${NC}"
echo -e "${BLUE}SSH Key: $SSH_KEY_PATH${NC}"
echo ""

# Test SSH connection before starting
if ! test_ssh_connection; then
    exit 1
fi

# Initial sync
$SCRIPT_DIR/echo-step.sh "Performing initial sync..."
sync_files

if [ "$WATCH_MODE" = false ]; then
    $SCRIPT_DIR/echo-success.sh "One-time sync completed. Exiting."
    exit 0
fi

$SCRIPT_DIR/echo-step.sh "Watching for changes... (Press Ctrl+C to stop)"
echo ""

# Watch for changes based on OS
if [[ "$FILE_WATCHER" == "fswatch" ]]; then
    # macOS: Use fswatch
    fswatch -r "$SOURCE_DIR" | while read file; do
        # Skip certain file types and directories
        if [[ "$file" =~ \.(git|node_modules|vendor|dev-workspace|tests|cursor|github|dist|log|env|babelrc|webpack|package|yarn|composer|makefile|codeception|phpcs|phplint|phpstan|phpmd|gitignore|gitattributes|gitmodules|distignore|rsync-filters|jsconfig|code-workspace|changelog|readme|license|mockups|docs|languages|lib) ]]; then
            continue
        fi

        # Skip if it's a directory we want to exclude
        if [[ "$file" =~ /(\.git|node_modules|vendor|dev-workspace|tests|\.cursor|\.github|dist|mockups|docs|languages|lib)/ ]]; then
            continue
        fi

        echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] Change detected: $file${NC}"
        sync_files
    done
else
    # Linux: Use inotifywait
    inotifywait -m -r -e modify,create,delete,move "$SOURCE_DIR" --format '%w%f %e' | while read file event; do
        # Skip certain file types and directories
        if [[ "$file" =~ \.(git|node_modules|vendor|dev-workspace|tests|cursor|github|dist|log|env|babelrc|webpack|package|yarn|composer|makefile|codeception|phpcs|phplint|phpstan|phpmd|gitignore|gitattributes|gitmodules|distignore|rsync-filters|jsconfig|code-workspace|changelog|readme|license|mockups|docs|languages|lib) ]]; then
            continue
        fi

        # Skip if it's a directory we want to exclude
        if [[ "$file" =~ /(\.git|node_modules|vendor|dev-workspace|tests|\.cursor|\.github|dist|mockups|docs|languages|lib)/ ]]; then
            continue
        fi

        echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] Change detected: $file ($event)${NC}"
        sync_files
    done
fi
