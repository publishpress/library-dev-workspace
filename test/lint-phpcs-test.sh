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

make_fixture() {
    local name="$1"
    local fixture="$TMP_ROOT/$name"

    mkdir -p \
        "$fixture/bin" \
        "$fixture/vendor/publishpress/publishpress-phpcs-standards/standards/plugin-check-rulesets"
    ln -s "$REPO_ROOT" "$fixture/vendor/publishpress/dev-workspace"

    cat > "$fixture/.env" <<'EOF'
PLUGIN_NAME=Fixture
PLUGIN_TYPE=plugin
PLUGIN_SLUG=fixture
PLUGIN_COMPOSER_PACKAGE=publishpress/fixture
CONTAINER_NAME=fixture
TERMINAL_IMAGE_NAME=fixture
CACHE_PATH=cache
LANG_DOMAIN=fixture
LANG_DIR=languages
LANG_LOCALES=en_US
EOF

    cat > "$fixture/.phpcs.xml" <<'EOF'
<?xml version="1.0"?>
<ruleset name="Fixture">
    <file>includes</file>
</ruleset>
EOF

    touch "$fixture/vendor/publishpress/publishpress-phpcs-standards/standards/plugin-check-rulesets/plugin-review.xml"

    cat > "$fixture/bin/phpcs" <<'EOF'
#!/usr/bin/env bash
{
    echo "CALL"
    printf 'ARG=%q\n' "$@"
} >> "$PHPCS_CALLS"
EOF
    chmod +x "$fixture/bin/phpcs"

    echo "$fixture"
}

run_lint() {
    local fixture="$1"
    shift

    : > "$fixture/phpcs-calls"
    (
        cd "$fixture"
        PATH="$fixture/bin:$PATH" \
            PHPCS_CALLS="$fixture/phpcs-calls" \
            bash "$fixture/vendor/publishpress/dev-workspace/scripts/lint-phpcs.sh" "$@"
    ) > "$fixture/lint-output"
}

assert_calls() {
    local name="$1"
    local fixture="$2"
    local expected="$3"
    local actual

    actual="$(< "$fixture/phpcs-calls")"
    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "expected [$expected], got [$actual]"
    fi
}

assert_output() {
    local name="$1"
    local fixture="$2"
    local expected="$3"
    local actual

    actual="$(< "$fixture/lint-output")"
    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "expected [$expected], got [$actual]"
    fi
}

bare_fixture="$(make_fixture bare)"
run_lint "$bare_fixture"
assert_calls "vendor fallback defaults to project root" "$bare_fixture" \
"CALL
ARG=-p
ARG=--standard=.phpcs.xml
CALL
ARG=-p
ARG=--standard=vendor/publishpress/publishpress-phpcs-standards/standards/plugin-check-rulesets/plugin-review.xml
ARG=."
assert_output "passes have clear progress labels" "$bare_fixture" \
"▶ PHPCS pass 1/2: project standards
▶ PHPCS pass 2/2: WordPress.org plugin review"

target_fixture="$(make_fixture explicit-targets)"
run_lint "$target_fixture" "includes/Foo.php" "path with spaces.php"
assert_calls "explicit targets are forwarded unchanged" "$target_fixture" \
"CALL
ARG=-p
ARG=--standard=.phpcs.xml
ARG=includes/Foo.php
ARG=path\\ with\\ spaces.php
CALL
ARG=-p
ARG=--standard=vendor/publishpress/publishpress-phpcs-standards/standards/plugin-check-rulesets/plugin-review.xml
ARG=includes/Foo.php
ARG=path\\ with\\ spaces.php"

project_fixture="$(make_fixture project-ruleset)"
touch "$project_fixture/.phpcs-plugin-review.xml"
run_lint "$project_fixture"
assert_calls "project ruleset keeps its configured paths" "$project_fixture" \
"CALL
ARG=-p
ARG=--standard=.phpcs.xml
CALL
ARG=-p
ARG=--standard=.phpcs-plugin-review.xml"

echo
echo "$passes passed, $failures failed"
exit "$((failures > 0 ? 1 : 0))"
