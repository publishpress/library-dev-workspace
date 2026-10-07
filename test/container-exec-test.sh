#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
passes=0
failures=0

trap 'rm -rf "$TMP_ROOT"' EXIT

pass() {
    passes=$((passes + 1))
    echo "PASS  $1"
}

fail() {
    failures=$((failures + 1))
    echo "FAIL  $1 — $2"
}

run_container_exec() {
    local project_dir="$1"
    local mount_dir="$2"
    shift 2

    # BusyBox ash is the terminal image shell. Ubuntu CI has dash as /bin/sh,
    # which accepts the same POSIX rewrite loop.
    local shell_bin="sh"
    if command -v busybox >/dev/null 2>&1; then
        shell_bin="busybox sh"
    fi

    env -u GIT_USER_NAME -u GIT_USER_EMAIL \
        CONTAINER_PROJECT_DIR="$project_dir" \
        DEV_WORKSPACE_MOUNT="$mount_dir" \
        $shell_bin -c "$(cat "$REPO_ROOT/scripts/container-exec.sh")" _ "$@"
}

write_script() {
    local path="$1"
    local message="$2"
    mkdir -p "$(dirname "$path")"
    cat > "$path" << EOF
#!/bin/sh
echo "$message"
printf 'ARG=%s\\n' "\$@"
EOF
    chmod +x "$path"
}

broken_project="$TMP_ROOT/broken-project"
broken_mount="$TMP_ROOT/broken-mount"
mkdir -p "$broken_project/vendor/publishpress" "$broken_mount/scripts"
ln -s /no/such/dev-workspace "$broken_project/vendor/publishpress/dev-workspace"
write_script "$broken_mount/scripts/dependency-versions.sh" "ran-mount"

broken_output="$(run_container_exec "$broken_project" "$broken_mount" \
    vendor/publishpress/dev-workspace/scripts/dependency-versions.sh --flag "hello world")"
if printf '%s\n' "$broken_output" | grep -qx "ran-mount" \
    && printf '%s\n' "$broken_output" | grep -qx "ARG=--flag" \
    && printf '%s\n' "$broken_output" | grep -qx "ARG=hello world"; then
    pass "broken vendor symlink runs the /opt package script"
else
    fail "broken vendor symlink runs the /opt package script" "$broken_output"
fi

real_project="$TMP_ROOT/real-project"
real_mount="$TMP_ROOT/real-mount"
write_script "$real_project/vendor/publishpress/dev-workspace/scripts/dependency-versions.sh" "ran-vendor"
write_script "$real_mount/scripts/dependency-versions.sh" "ran-mount"

real_output="$(run_container_exec "$real_project" "$real_mount" \
    vendor/publishpress/dev-workspace/scripts/dependency-versions.sh)"
if printf '%s\n' "$real_output" | grep -qx "ran-vendor"; then
    pass "real vendor directory keeps the project script"
else
    fail "real vendor directory keeps the project script" "$real_output"
fi

# Inside the terminal, a script launched from the direct package mount must
# still read the plugin checkout at /project (here, the fixture project).
env_project="$TMP_ROOT/env-project"
mkdir -p "$env_project"
cat > "$env_project/composer.json" << 'EOF'
{"name":"publishpress/fixture"}
EOF
cat > "$env_project/.env" << 'EOF'
PLUGIN_NAME="Fixture"
PLUGIN_TYPE="FREE"
PLUGIN_SLUG="fixture"
PLUGIN_COMPOSER_PACKAGE="publishpress/fixture"
CONTAINER_NAME="fixture"
TERMINAL_IMAGE_NAME="fixture"
CACHE_PATH="./dev-workspace-cache"
LANG_DOMAIN="fixture"
LANG_DIR="languages"
LANG_LOCALES="en_US"
REPO_ROOT="/host/not/inside/this/container"
DEV_WORKSPACE_REAL="/host/not/inside/this/container/vendor/publishpress/dev-workspace"
EOF

env_output="$(
    INSIDE_DEV_CONTAINER=true \
        CONTAINER_PROJECT_DIR="$env_project" \
        bash -c 'source "$1"; printf "REPO_ROOT=%s\n" "$REPO_ROOT"' \
        _ "$REPO_ROOT/scripts/env-bootstrap.sh" 2>&1
)" || true
if printf '%s\n' "$env_output" | grep -qx "REPO_ROOT=$env_project"; then
    pass "container bootstrap uses the /project checkout"
else
    fail "container bootstrap uses the /project checkout" "$env_output"
fi

echo
echo "$passes passed, $failures failed"
if [ "$failures" -ne 0 ]; then
    exit 1
fi
