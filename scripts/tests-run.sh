#!/usr/bin/env bash
#
# Wrapper for Codeception test runs.
# Always ensures the Docker test stack is up before Codeception runs. Previously we
# only started it when the DB cache dir was empty; that skips `compose up` when the
# host has leftover db_test data but containers are stopped, leading to SQLSTATE[HY000] 2002
# Connection refused from WPLoader.
#
# Usage: tests-run.sh [codecept args...]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

show_help() {
    echo "Script to run the tests"
    echo "Usage: tests-run.sh [codecept args...]"
    echo ""
    echo "Example:"
    echo "tests-run.sh"
    echo "tests-run.sh test"
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

# If argument is explicitly "unit", don't bring up the test stack
if [ "$1" != "Unit" ]; then
    echo "Ensuring Docker test stack (MariaDB/WP/Mailhog) is running..."
    bash "$SCRIPT_DIR/server.sh" up test
fi

(cd "$REPO_ROOT" && vendor/bin/codecept run "$@")

$SCRIPT_DIR/echo-success.sh "Tests completed"
