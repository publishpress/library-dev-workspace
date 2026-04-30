#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

show_help() {
    echo "Script to export the test database"
    echo "Usage: tests-db-export.sh"
    echo ""
    echo "Example:"
    echo "tests-db-export.sh"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

cd "$DEV_WORKSPACE_DIR"

DB_EXPORT_FILE=/var/www/html/wp-content/plugins/$PLUGIN_SLUG/tests/Support/Data/dump.sql

bash "$SCRIPT_DIR/tests-wp-cli.sh" wp_test_cli db export "$DB_EXPORT_FILE"

$SCRIPT_DIR/echo-success.sh "Database exported to $DB_EXPORT_FILE"
