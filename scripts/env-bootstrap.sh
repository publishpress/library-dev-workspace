#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Script to bootstrap the environment"
    echo "Usage: env-bootstrap.sh"
    echo ""
    echo "Example:"
    echo "env-bootstrap.sh"
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

DEV_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Assuming the script is run from the dev-workspace/scripts directory.
DEV_WORKSPACE_DIR="$(cd "$DEV_SCRIPTS_DIR/.." && pwd)"
# Assuming the script is run from the dev-workspace directory from inside vendor/publishpress/dev-workspace.
REPO_ROOT="$(cd "$DEV_WORKSPACE_DIR/../../.." && pwd)"

export DEV_SCRIPTS_DIR DEV_WORKSPACE_DIR REPO_ROOT

if [[ ! -f "$REPO_ROOT/.env" ]]; then
    $DEV_SCRIPTS_DIR/echo-error.sh "Error: Missing .env file in repository root ($REPO_ROOT). Create it with: cp .env.example .env"
    exit 1
fi

set -a
source "$REPO_ROOT/.env"
set +a

if [[ "$CACHE_PATH" != /* ]]; then
    CACHE_PATH="$REPO_ROOT/$CACHE_PATH"
fi

required_env_vars=(
    "PLUGIN_NAME"
    "PLUGIN_TYPE"
    "PLUGIN_SLUG"
    "PLUGIN_COMPOSER_PACKAGE"
    "CONTAINER_NAME"
    "TERMINAL_IMAGE_NAME"
    "CACHE_PATH"
    "LANG_DOMAIN"
    "LANG_DIR"
    "LANG_LOCALES"
    "OPENAI_API_KEY"
    "WEBLATE_API_TOKEN"
    "WEBLATE_API_URL"
)

for var in "${required_env_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        $DEV_SCRIPTS_DIR/echo-error.sh "Error: $var is not set. Please set it in the .env file."
        exit 2
    fi
done
