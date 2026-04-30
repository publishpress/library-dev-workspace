#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

show_help() {
    echo "Script to run WP-CLI commands in the test container"
    echo "Usage: tests-wp-cli.sh <command>"
    echo ""
    echo "Example:"
    echo "tests-wp-cli.sh wp user create --role=administrator test@example.com --user_pass=password"
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

cd "$DEV_WORKSPACE_DIR"

SERVICE_NAME=$arg1
shift 1

# Check if wp-cli container is running, if not start it
if ! docker compose --env-file "$REPO_ROOT/.env" -f docker/compose.yaml ps | grep -q "_env_$SERVICE_NAME.*Up"; then
    $SCRIPT_DIR/echo-step.sh "Starting $SERVICE_NAME container..."
    docker compose --env-file "$REPO_ROOT/.env" -f docker/compose.yaml up -d $SERVICE_NAME
fi

# Execute WP-CLI command and pass all arguments
$SCRIPT_DIR/echo-step.sh "Running: wp $@"
docker compose --env-file "$REPO_ROOT/.env" -f docker/compose.yaml exec $SERVICE_NAME wp "$@"

$SCRIPT_DIR/echo-success.sh "WP-CLI command executed successfully"
