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

echo
echo "$passes passed, $failures failed"
exit "$((failures > 0 ? 1 : 0))"
