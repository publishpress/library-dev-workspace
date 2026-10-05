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
if [ "${1:-}" != "Unit" ]; then
    echo "Ensuring Docker test stack (MariaDB/WP/Mailhog) is running..."
    bash "$SCRIPT_DIR/server.sh" up test

    # compose marks wp_test_cli healthy as soon as it starts. Wait until
    # prepare-wp.sh has decided not to reset the database.
    cli_container="${CONTAINER_NAME}_env_wp_test_cli"
    echo "Waiting for ${cli_container} to finish database setup..."
    deadline=$((SECONDS + 600))
    while true; do
        cli_status="$(docker inspect -f '{{.State.Status}}' "$cli_container" 2>/dev/null || echo missing)"
        if [ "$cli_status" = "exited" ]; then
            cli_exit="$(docker inspect -f '{{.State.ExitCode}}' "$cli_container")"
            echo "WordPress test CLI setup exited ${cli_exit}" >&2
            docker logs --tail 40 "$cli_container" >&2 || true
            exit 1
        fi
        if docker exec "$cli_container" test -f /tmp/wp-test-ready; then
            break
        fi
        if [ "$SECONDS" -ge "$deadline" ]; then
            echo "Timed out waiting for ${cli_container} (status: ${cli_status})" >&2
            exit 1
        fi
        sleep 1
    done
fi

(cd "$REPO_ROOT" && vendor/bin/codecept run "$@")

$SCRIPT_DIR/echo-success.sh "Tests completed"
