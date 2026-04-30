#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

bash "$SCRIPT_DIR/services-init-cache.sh"

CACHE_NAME_LAST_UPDATE="$CACHE_PATH/.last_image_update_check"
ONE_DAY_IN_SECONDS=86400
UPDATE_CHECK_INTERVAL=$ONE_DAY_IN_SECONDS
DEFAULT_SOURCE_PATH="${GITHUB_WORKSPACE:-/project}"

run_terminal_service() {
    if [ $# -eq 0 ]; then
        docker compose --env-file "$REPO_ROOT/.env" -f docker/compose.yaml run --rm terminal zsh -lc 'if [ -n "$GIT_USER_NAME" ]; then git config --global user.name "$GIT_USER_NAME"; fi; if [ -n "$GIT_USER_EMAIL" ]; then git config --global user.email "$GIT_USER_EMAIL"; fi; exec zsh'
    else
        docker compose --env-file "$REPO_ROOT/.env" -f docker/compose.yaml run --rm terminal sh -c '
            export DEV_WORKSPACE_DIR="$DEFAULT_SOURCE_PATH/vendor/publishpress/dev-workspace"
            export PATH="$DEV_WORKSPACE_DIR/scripts:$PATH"
            [ -n "$GIT_USER_NAME" ] && git config --global user.name "$GIT_USER_NAME"
            [ -n "$GIT_USER_EMAIL" ] && git config --global user.email "$GIT_USER_EMAIL"
            exec "$@"
        ' _ "$@"
    fi
}

configure_git_identity_existing_container() {
    local container_id=$1
    docker exec -i "$container_id" zsh -lc 'if [ -n "$GIT_USER_NAME" ]; then git config --global user.name "$GIT_USER_NAME"; fi; if [ -n "$GIT_USER_EMAIL" ]; then git config --global user.email "$GIT_USER_EMAIL"; fi'
}

bash "$SCRIPT_DIR/services-pull-images.sh" --daily

RUNNING_CONTAINER=$(bash "$SCRIPT_DIR/terminal-detect-running-container.sh")

show_help() {
    echo "Script to run the terminal service"
    echo "Usage: terminal-service-run.sh [--new|-n|--help|-h]"
    echo ""
    echo "Example:"
    echo "terminal-service-run.sh --new"
    echo "terminal-service-run.sh -n"
    echo "terminal-service-run.sh --help"
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

HAS_NO_COMMAND=true
for arg in "$@"; do
    if [ "$arg" = "--new" ] || [ "$arg" = "-n" ]; then
        HAS_NO_COMMAND=false
        break
    fi
done

if [ "$1" = "--new" ] || [ "$1" = "-n" ]; then
    if [ "$HAS_NO_COMMAND" = false ]; then
        $SCRIPT_DIR/echo-step.sh "Running new container"
    fi
    run_terminal_service "${@:2}"
elif [ -z "$RUNNING_CONTAINER" ]; then
    if [ "$HAS_NO_COMMAND" = false ]; then
        $SCRIPT_DIR/echo-step.sh "Running new container"
    fi
    run_terminal_service "$@"
else
    if [ "$HAS_NO_COMMAND" = false ]; then
        $SCRIPT_DIR/echo-step.sh "Running existing container"
    fi
    configure_git_identity_existing_container "$RUNNING_CONTAINER"
    if [ $# -eq 0 ]; then
        docker exec -it "$RUNNING_CONTAINER" zsh
    else
        docker exec -it "$RUNNING_CONTAINER" "$@"
    fi
fi
