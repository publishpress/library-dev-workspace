#!/usr/bin/env bash
#
# Wrapper for Codeception test runs.
# Auto-starts the test environment when the DB data directory is missing,
# which prevents SQLSTATE[HY000] errno=1018 errors on the first run or
# after composer test:clean-cache.
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

CACHE_DB="$CACHE_PATH/db_test"

if [[ ! -d "$CACHE_DB" ]] || [[ -z "$(ls -A "$CACHE_DB" 2>/dev/null)" ]]; then
    echo "Test DB cache not found — starting test environment..."
    bash "$SCRIPT_DIR/server.sh" up test
fi

(cd "$REPO_ROOT" && vendor/bin/codecept run "$@")

$SCRIPT_DIR/echo-success.sh "Tests completed"
