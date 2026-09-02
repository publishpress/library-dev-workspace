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

assert_same() {
    local name="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "expected [$expected], got [$actual]"
    fi
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

write_fixture() {
    local version="$1"

    cat > "$TMP_ROOT/composer.json" <<'JSON'
{
  "name": "publishpress/demo-plugin",
  "extra": {
    "plugin-slug": "demo-plugin",
    "version-constant": "DEMO_PLUGIN_VERSION"
  }
}
JSON

    cat > "$TMP_ROOT/demo-plugin.php" <<PHP
<?php
/**
 * Plugin Name: Demo Plugin
 * Version: ${version}
 */

define('DEMO_PLUGIN_VERSION', '${version}');
PHP
}

write_stable_fixture_file() {
    local fixture_dir="$1"
    local version="$2"
    shift 2

    mkdir -p "$fixture_dir"

    cat > "$fixture_dir/composer.json" <<'JSON'
{
  "name": "publishpress/demo-plugin",
  "extra": {
    "plugin-slug": "demo-plugin",
    "version-constant": "DEMO_PLUGIN_VERSION"
  }
}
JSON

    printf 'Stable tag: %s\n' "$version" > "$fixture_dir/readme.txt"

    while [[ $# -ge 2 ]]; do
        local relative="$1"
        local contents="$2"
        shift 2
        printf '%s\n' "$contents" > "$fixture_dir/${relative}"
    done
}

run_check_release() {
    local fixture_dir="$1"
    local version="$2"
    PP_SOURCE_PATH="$fixture_dir" bash "$REPO_ROOT/scripts/check-release.sh" "$version" 2>&1
}

versions=(
    "3.111.1-beta1"
    "1.2.3-beta.1+build.7"
    "1.2.3+build.7"
)

for version in "${versions[@]}"; do
    write_fixture "$version"
    actual="$(bash "$REPO_ROOT/scripts/plugin-version.sh" "$TMP_ROOT")"
    assert_same "plugin-version preserves $version" "$version" "$actual"
done

write_fixture "3.111.1-beta1"
if release_output="$(PP_SOURCE_PATH="$TMP_ROOT" bash "$REPO_ROOT/scripts/check-release.sh" --if-stable 2>&1)"; then
    pass "check-release skips beta1 prerelease"
else
    fail "check-release skips beta1 prerelease" "$release_output"
fi
assert_contains "check-release reports complete prerelease" "$release_output" "3.111.1-beta1 is not a stable release"

if wporg_output="$(PP_SOURCE_PATH="$TMP_ROOT" bash "$REPO_ROOT/scripts/check-wporg.sh" 2>&1)"; then
    fail "check-wporg rejects beta1 prerelease before network checks" "expected exit 1"
else
    wporg_status=$?
    assert_same "check-wporg prerelease exit code" "1" "$wporg_status"
fi
assert_contains "check-wporg reports complete prerelease" "$wporg_output" "got '3.111.1-beta1'"

CONST_FIXTURE="$TMP_ROOT/constant-fixtures"
mkdir -p "$CONST_FIXTURE"

MAIN_ONLY_HEADER='<?php
/**
 * Plugin Name: Demo Plugin
 * Version: 2.0.0
 */'

write_stable_fixture_file "$CONST_FIXTURE/defines-only" "2.0.0" \
    "demo-plugin.php" "$MAIN_ONLY_HEADER" \
    "defines.php" "define('DEMO_PLUGIN_VERSION', '2.0.0');"

defines_only_output="$(run_check_release "$CONST_FIXTURE/defines-only" "2.0.0")"
assert_contains "check-release accepts constant in defines.php" "$defines_only_output" "Version constant: DEMO_PLUGIN_VERSION=2.0.0 (defines.php)"

write_stable_fixture_file "$CONST_FIXTURE/duplicate" "2.0.0" \
    "demo-plugin.php" "${MAIN_ONLY_HEADER}

define('DEMO_PLUGIN_VERSION', '2.0.0');" \
    "defines.php" "define('DEMO_PLUGIN_VERSION', '2.0.0');"

if duplicate_output="$(run_check_release "$CONST_FIXTURE/duplicate" "2.0.0")"; then
    fail "check-release rejects duplicate constant locations" "$duplicate_output"
else
    pass "check-release rejects duplicate constant locations"
fi
assert_contains "check-release reports duplicate constant files" "$duplicate_output" "defined in multiple files: demo-plugin.php defines.php"

write_stable_fixture_file "$CONST_FIXTURE/missing" "2.0.0" \
    "demo-plugin.php" "$MAIN_ONLY_HEADER"

if missing_output="$(run_check_release "$CONST_FIXTURE/missing" "2.0.0")"; then
    fail "check-release rejects missing version constant" "$missing_output"
else
    pass "check-release rejects missing version constant"
fi
assert_contains "check-release reports missing constant" "$missing_output" "not found in main plugin file, defines.php, constants.php, or include.php"

write_stable_fixture_file "$CONST_FIXTURE/mismatch" "2.0.0" \
    "demo-plugin.php" "$MAIN_ONLY_HEADER" \
    "constants.php" "define('DEMO_PLUGIN_VERSION', '1.0.0');"

if mismatch_output="$(run_check_release "$CONST_FIXTURE/mismatch" "2.0.0")"; then
    fail "check-release rejects mismatched constant value" "$mismatch_output"
else
    pass "check-release rejects mismatched constant value"
fi
assert_contains "check-release reports constant mismatch basename" "$mismatch_output" "got '1.0.0' (constants.php)"

echo
echo "$passes passed, $failures failed"
exit "$((failures > 0 ? 1 : 0))"
