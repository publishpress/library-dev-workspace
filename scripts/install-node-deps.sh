#!/usr/bin/env bash
set -euo pipefail

show_help() {
    echo "Install Node.js dependencies for a package directory."
    echo ""
    echo "Usage: install-node-deps.sh [project_dir] [required_binary ...]"
    echo ""
    echo "Uses Yarn when available (preferred), otherwise npm."
    echo "Skips when package.json is missing and dependencies are already satisfied."
    echo "If required_binary names are given, install runs when any are missing from node_modules/.bin."
    echo ""
    echo "project_dir       Path containing package.json (default: dev-workspace root)"
    echo "required_binary   Optional CLI names to require (e.g. po2json)"
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REQUIRED_BINS=()

if [ -n "${1:-}" ] && [ -f "${1}/package.json" ]; then
    PROJECT_DIR="$(cd "$1" && pwd)"
    shift
fi

REQUIRED_BINS=("$@")

if [ ! -f "${PROJECT_DIR}/package.json" ]; then
    exit 0
fi

needs_install=0

if [ ! -d "${PROJECT_DIR}/node_modules" ] || [ -z "$(ls -A "${PROJECT_DIR}/node_modules" 2>/dev/null)" ]; then
    needs_install=1
fi

if [ "${#REQUIRED_BINS[@]}" -gt 0 ]; then
    for required_bin in "${REQUIRED_BINS[@]}"; do
        if [ ! -x "${PROJECT_DIR}/node_modules/.bin/${required_bin}" ]; then
            needs_install=1
            break
        fi
    done
fi

if [ "${needs_install}" -eq 0 ]; then
    exit 0
fi

run_yarn_install() {
    local yarn_version
    yarn_version="$(yarn --version 2>/dev/null | cut -d. -f1)"

    if [ -f "${PROJECT_DIR}/yarn.lock" ]; then
        if [ "${yarn_version}" = "1" ]; then
            (cd "${PROJECT_DIR}" && yarn install --frozen-lockfile --non-interactive)
        else
            (cd "${PROJECT_DIR}" && yarn install --immutable)
        fi
    else
        (cd "${PROJECT_DIR}" && yarn install --non-interactive)
    fi
}

run_npm_install() {
    if [ -f "${PROJECT_DIR}/package-lock.json" ]; then
        (cd "${PROJECT_DIR}" && npm ci --no-audit --no-fund)
    else
        (cd "${PROJECT_DIR}" && npm install --no-audit --no-fund)
    fi
}

if command -v yarn >/dev/null 2>&1; then
    run_yarn_install
else
    run_npm_install
fi
