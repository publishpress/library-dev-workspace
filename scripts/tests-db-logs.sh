#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

show_help() {
    echo "Script to enable or disable the MySQL general log"
    echo "Usage: tests-db-logs.sh [on|off]"
    echo ""
    echo "Example:"
    echo "tests-db-logs.sh on"
    echo "tests-db-logs.sh off"
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

cd "$DEV_WORKSPACE_DIR"

DB_CONTAINER_NAME=${CONTAINER_NAME}_env_db_test
DB_LOGS_FILE="$REPO_ROOT/dev-workspace-cache/logs/db_test/general.log"

run_mysql_query() {
  docker exec -i $DB_CONTAINER_NAME bash -c "mysql -u root -proot -e '$1' 2>&1 | grep  -v \"Using a password\""
}

if [[ $1 == "off" ]]; then
  run_mysql_query "SET GLOBAL general_log = OFF;"
  $SCRIPT_DIR/echo-success.sh "MySQL general log is disabled."
else
  run_mysql_query "SET GLOBAL general_log = ON;"
  $SCRIPT_DIR/echo-success.sh "MySQL general log is enabled. Check the logs at ${DB_LOGS_FILE}"
fi
