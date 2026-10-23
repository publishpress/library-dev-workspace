#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
CHANGELOG="$TMP_ROOT/CHANGELOG.md"
STAMP="$TMP_ROOT/.dev_workspace_last_seen_version"
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

assert_not_contains() {
    local name="$1"
    local haystack="$2"
    local needle="$3"

    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$name"
    else
        fail "$name" "expected output not to contain [$needle], got [$haystack]"
    fi
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

write_changelog() {
    cat > "$CHANGELOG" <<'CHANGELOG_EOF'
# Changelog

[Unreleased]

- SHOULD_NOT_SHOW_UNRELEASED

[2.0.2] - 23 Oct, 2026

- ENTRY_202

[2.0.1] - 22 Oct, 2026

- ENTRY_201

[2.0.0] - 22 Oct, 2026

- ENTRY_200
CHANGELOG_EOF
}

run_notice() {
    local fresh="${1:-0}"
    if [[ "$fresh" -eq 1 ]]; then
        rm -f "$STAMP"
    fi
    bash "$REPO_ROOT/scripts/update-notice.sh" --force --changelog "$CHANGELOG" --stamp "$STAMP"
}

write_changelog

output="$(run_notice 1)"
assert_contains "first run shows unknown previous" "$output" "previous version unknown"
assert_contains "first run shows current entry" "$output" "ENTRY_202"
assert_not_contains "first run skips older entries" "$output" "ENTRY_201"
assert_not_contains "first run skips unreleased" "$output" "SHOULD_NOT_SHOW_UNRELEASED"
assert_same "first run writes stamp" "2.0.2" "$(tr -d '[:space:]' < "$STAMP")"

printf '%s\n' "1.8.19" > "$STAMP"
output="$(run_notice)"
assert_contains "upgrade shows 2.0.0" "$output" "ENTRY_200"
assert_contains "upgrade shows 2.0.1" "$output" "ENTRY_201"
assert_contains "upgrade shows 2.0.2" "$output" "ENTRY_202"
assert_contains "upgrade title" "$output" "1.8.19 -> 2.0.2"

printf '%s\n' "2.0.2" > "$STAMP"
output="$(run_notice)"
assert_same "same version silent output" "" "$output"
assert_same "same version stamp" "2.0.2" "$(tr -d '[:space:]' < "$STAMP")"

printf '%s\n' "3.0.0" > "$STAMP"
output="$(run_notice)"
assert_same "downgrade silent output" "" "$output"
assert_same "downgrade updates stamp" "2.0.2" "$(tr -d '[:space:]' < "$STAMP")"

echo
echo "$passes passed, $failures failed"
exit "$((failures > 0 ? 1 : 0))"
