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

DEV_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"
# Logical path keeps vendor/... layout when the package is a Composer path symlink.
DEV_WORKSPACE_DIR="$(cd "$DEV_SCRIPTS_DIR/.." && pwd -L)"
# Physical path for Docker bind-mounts (symlink targets live outside the plugin mount).
DEV_WORKSPACE_REAL="$(cd "$DEV_SCRIPTS_DIR/.." && pwd -P)"
# Assuming the script is run from the dev-workspace directory from inside vendor/publishpress/dev-workspace.
computed_repo_root="$(cd "$DEV_WORKSPACE_DIR/../../.." && pwd -L)"
REPO_ROOT="$computed_repo_root"

export DEV_SCRIPTS_DIR DEV_WORKSPACE_DIR DEV_WORKSPACE_REAL REPO_ROOT

if [[ ! -f "$REPO_ROOT/.env" ]]; then
    $DEV_SCRIPTS_DIR/echo-error.sh "Error: Missing .env file in repository root ($REPO_ROOT). Create it with: cp .env.example .env"
    exit 1
fi

set -a
source "$REPO_ROOT/.env"
set +a

# .env stores the host checkout path so Docker Compose can interpolate
# ${REPO_ROOT}:/project. The terminal container mounts that checkout at
# /project, so the host path is not present there. Keep using the checkout
# this process was launched from.
host_repo_root="$REPO_ROOT"
if [[ ! -f "$REPO_ROOT/composer.json" && -f "$computed_repo_root/composer.json" ]]; then
    REPO_ROOT="$computed_repo_root"
    export REPO_ROOT
fi

if [[ "$CACHE_PATH" != /* ]]; then
    CACHE_PATH="$REPO_ROOT/$CACHE_PATH"
fi
export CACHE_PATH

# Docker Compose --env-file interpolates compose.yaml from the file, not from
# the process environment (Compose v5). Persist the host checkout path so
# ${REPO_ROOT}:/project does not become :/project. Skip this inside the
# terminal container: writing /project back into .env breaks the next
# host-side Compose run.
upsert_dotenv() {
    local file="$1" key="$2" value="$3"
    local tmp
    tmp="$(mktemp)"
    awk -v k="$key" -v v="$value" '
        BEGIN { done = 0 }
        $0 ~ "^" k "=" {
            print k "=\"" v "\""
            done = 1
            next
        }
        { print }
        END { if (!done) print k "=\"" v "\"" }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
}

if [[ "${INSIDE_DEV_CONTAINER:-}" != "true" && -f "$host_repo_root/composer.json" ]]; then
    upsert_dotenv "$host_repo_root/.env" REPO_ROOT "$host_repo_root"
    upsert_dotenv "$host_repo_root/.env" DEV_WORKSPACE_REAL "$DEV_WORKSPACE_REAL"
    upsert_dotenv "$host_repo_root/.env" CACHE_PATH "$CACHE_PATH"
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
)

for var in "${required_env_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        $DEV_SCRIPTS_DIR/echo-error.sh "Error: $var is not set. Please set it in the .env file."
        exit 2
    fi
done
