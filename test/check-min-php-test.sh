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

assert_contains() {
    local name="$1"
    local haystack="$2"
    local needle="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$name"
    else
        fail "$name" "expected output to contain [$needle], got [$haystack]"
    fi
}

# write_fixture DIR README_PHP HEADER_PHP COMPOSER_PHP GUARD
write_fixture() {
    local dir="$1"
    local readme_php="$2"
    local header_php="$3"
    local composer_php="$4"
    local guard="$5"

    mkdir -p "$dir"

    jq -n --arg php "$composer_php" '
        {name: "publishpress/demo-plugin", extra: {"plugin-slug": "demo-plugin"}}
        + (if $php == "" then {} else {require: {php: $php}} end)
    ' > "$dir/composer.json"

    {
        echo "=== Demo Plugin ==="
        echo "Stable tag: 1.0.0"
        if [[ -n "$readme_php" ]]; then
            echo "Requires PHP: ${readme_php}"
        fi
    } > "$dir/readme.txt"

    {
        echo "<?php"
        echo "/**"
        echo " * Plugin Name: Demo Plugin"
        echo " * Version: 1.0.0"
        if [[ -n "$header_php" ]]; then
            echo " * Requires PHP: ${header_php}"
        fi
        echo " */"
        echo ""
        printf '%s\n' "$guard"
    } > "$dir/demo-plugin.php"
}

run_check() {
    bash "$REPO_ROOT/scripts/check-min-php.sh" "$@" 2>&1
}

expect_pass() {
    local name="$1"
    shift
    local output
    if output="$(run_check "$@")"; then
        pass "$name"
    else
        fail "$name" "$output"
    fi
}

expect_fail() {
    local name="$1"
    local needle="$2"
    shift 2
    local output
    if output="$(run_check "$@")"; then
        fail "$name" "expected exit 1, got [$output]"
    else
        assert_contains "$name" "$output" "$needle"
    fi
}

VAR_GUARD="\$min_php_version = '8.2';
if (version_compare(phpversion(), \$min_php_version, '<')) {
    return;
}"

write_fixture "$TMP_ROOT/var-guard" "8.2" "8.2" ">=8.2" "$VAR_GUARD"
expect_pass "accepts variable guard with phpversion()" "$TMP_ROOT/var-guard"

write_fixture "$TMP_ROOT/const-guard" "8.2.0" "8.2" "^8.2" "const DEMO_MINIMUM_PHP_VERSION = '8.2';
if (version_compare(PHP_VERSION, DEMO_MINIMUM_PHP_VERSION, '<')) {
    return;
}"
expect_pass "accepts const guard, 8.2.0 readme, caret constraint" "$TMP_ROOT/const-guard"

write_fixture "$TMP_ROOT/literal-guard" "8.2" "8.2" ">=8.2.0" "if (version_compare(phpversion(), '8.2', '<') || version_compare(\$wp_version, '6.8', '<')) {
    return;
}"
expect_pass "accepts literal guard" "$TMP_ROOT/literal-guard"

write_fixture "$TMP_ROOT/id-guard" "8.2" "8.2" ">=8.2" "if (PHP_VERSION_ID < 80200) {
    return;
}"
expect_pass "accepts PHP_VERSION_ID guard" "$TMP_ROOT/id-guard"

write_fixture "$TMP_ROOT/old-readme" "7.4" "8.2" ">=8.2" "$VAR_GUARD"
expect_fail "rejects old readme Requires PHP" "readme.txt Requires PHP: expected 8.2, got '7.4'" "$TMP_ROOT/old-readme"

write_fixture "$TMP_ROOT/no-header" "8.2" "" ">=8.2" "$VAR_GUARD"
expect_fail "rejects missing header Requires PHP" "Plugin header Requires PHP: expected 8.2, got 'missing'" "$TMP_ROOT/no-header"

write_fixture "$TMP_ROOT/no-guard" "8.2" "8.2" ">=8.2" "// no guard"
expect_fail "rejects missing guard" "Main plugin file PHP guard: no version_compare(phpversion()|PHP_VERSION, ...) or PHP_VERSION_ID guard found" "$TMP_ROOT/no-guard"

write_fixture "$TMP_ROOT/old-guard" "8.2" "8.2" ">=8.2" "\$min_php_version = '7.4';
if (version_compare(phpversion(), \$min_php_version, '<')) {
    return;
}"
expect_fail "rejects old guard version" "Main plugin file PHP guard: expected 8.2, got '7.4'" "$TMP_ROOT/old-guard"

write_fixture "$TMP_ROOT/no-composer-php" "8.2" "8.2" "" "$VAR_GUARD"
expect_fail "rejects missing composer require.php" "composer.json require.php: expected >=8.2, got 'missing'" "$TMP_ROOT/no-composer-php"

write_fixture "$TMP_ROOT/old-composer-php" "8.2" "8.2" ">=7.4" "$VAR_GUARD"
expect_fail "rejects old composer require.php" "composer.json require.php: expected >=8.2, got '>=7.4'" "$TMP_ROOT/old-composer-php"

write_fixture "$TMP_ROOT/custom-version" "8.3" "8.3" ">=8.3" "if (PHP_VERSION_ID < 80300) {
    return;
}"
expect_pass "accepts --version override" --version=8.3 "$TMP_ROOT/custom-version"

echo
echo "$passes passed, $failures failed"
exit "$((failures > 0 ? 1 : 0))"
