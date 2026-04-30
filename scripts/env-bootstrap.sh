#!/usr/bin/env bash

DEV_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_WORKSPACE_DIR="$(cd "$DEV_SCRIPTS_DIR/.." && pwd)"
REPO_ROOT="$(cd "$DEV_WORKSPACE_DIR/../../.." && pwd)"

# Subprocesses (e.g. pack.sh spawned from run.sh) must inherit these paths.
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
