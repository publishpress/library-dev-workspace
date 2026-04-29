#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-init.sh"
cd "$DEV_WORKSPACE_DIR"

DB_EXPORT_FILE=/var/www/html/wp-content/plugins/$PLUGIN_SLUG/tests/Support/Data/dump.sql

bash "$DEV_SCRIPTS_DIR/tests-wp-cli.sh" wp_test_cli db export "$DB_EXPORT_FILE"
