#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
passes=0
failures=0
RUN_OUTPUT=""
RUN_STATUS=0

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

make_fixture() {
    local name="$1"
    local include_plugin_folder="$2"
    local fixture="$TMP_ROOT/$name"

    mkdir -p \
        "$fixture/admin/assets/dist" \
        "$fixture/bin" \
        "$fixture/dist/fixture-plugin" \
        "$fixture/dist/fixture-plugin-tmp" \
        "$fixture/languages" \
        "$fixture/vendor/publishpress"
    ln -s "$REPO_ROOT" "$fixture/vendor/publishpress/dev-workspace"

    cat > "$fixture/.env" <<'EOF'
PLUGIN_NAME=Fixture
PLUGIN_TYPE=plugin
PLUGIN_SLUG=fixture
PLUGIN_COMPOSER_PACKAGE=publishpress/fixture
CONTAINER_NAME=fixture
TERMINAL_IMAGE_NAME=fixture
CACHE_PATH=cache
LANG_DOMAIN=fixture-domain
LANG_DIR=languages
LANG_LOCALES=en_US
EOF

    if [[ "$include_plugin_folder" == "yes" ]]; then
        cat > "$fixture/composer.json" <<'JSON'
{
  "name": "publishpress/fixture",
  "extra": {
    "plugin-folder": "fixture-plugin"
  }
}
JSON
    else
        cat > "$fixture/composer.json" <<'JSON'
{
  "name": "publishpress/fixture",
  "extra": {}
}
JSON
    fi

    cat > "$fixture/bin/wp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" >> "$WP_CALLS"

if [[ "${WP_FAIL:-0}" == "1" ]]; then
    exit 7
fi

if [[ "${WP_SKIP_OUTPUT:-0}" != "1" ]]; then
    mkdir -p "$(dirname "$4")"
    printf 'fixture pot\n' > "$4"
fi
EOF
    chmod +x "$fixture/bin/wp"

    echo "$fixture"
}

run_translate() {
    local fixture="$1"
    shift

    : > "$fixture/wp-calls"
    if RUN_OUTPUT="$(
        cd "$fixture"
        env \
            PATH="$fixture/bin:$PATH" \
            WP_CALLS="$fixture/wp-calls" \
            "$@" \
            bash "$fixture/vendor/publishpress/dev-workspace/scripts/translate-pot.sh" 2>&1
    )"; then
        RUN_STATUS=0
    else
        RUN_STATUS=$?
    fi
}

success_fixture="$(make_fixture success yes)"
run_translate "$success_fixture"
assert_same "translate-pot succeeds" "0" "$RUN_STATUS"
assert_same "translate-pot passes narrowed paths to WP-CLI" \
"i18n
make-pot
$success_fixture
$success_fixture/languages/fixture-domain.pot
--domain=fixture-domain
--exclude=vendor,.wordpress-org,.github,.cursor,.claude,.vscode,dist/fixture-plugin,dist/fixture-plugin-tmp,tests,lib/vendor,tmp,doc,docs,.cache,dev-workspace-cache,.node_modules,.git,.zed,languages
--allow-root" \
"$(< "$success_fixture/wp-calls")"
if [[ -f "$success_fixture/languages/fixture-domain.pot" ]]; then
    pass "translate-pot creates the POT file"
else
    fail "translate-pot creates the POT file" "POT file is missing"
fi

wp_failure_fixture="$(make_fixture wp-failure yes)"
run_translate "$wp_failure_fixture" WP_FAIL=1
assert_same "translate-pot preserves WP-CLI failure status" "3" "$RUN_STATUS"
assert_contains "translate-pot reports WP-CLI failure" "$RUN_OUTPUT" "Failed to create POT file"

missing_pot_fixture="$(make_fixture missing-pot yes)"
run_translate "$missing_pot_fixture" WP_SKIP_OUTPUT=1
assert_same "translate-pot rejects a missing POT output" "2" "$RUN_STATUS"
assert_contains "translate-pot reports a missing POT output" "$RUN_OUTPUT" "POT file was not created"

missing_metadata_fixture="$(make_fixture missing-metadata no)"
run_translate "$missing_metadata_fixture"
assert_same "translate-pot rejects missing plugin-folder metadata" "4" "$RUN_STATUS"
assert_contains "translate-pot reports missing plugin-folder metadata" "$RUN_OUTPUT" "Unable to determine the plugin folder"
assert_same "translate-pot does not invoke WP-CLI without plugin-folder metadata" "" "$(< "$missing_metadata_fixture/wp-calls")"

echo
echo "$passes passed, $failures failed"
exit "$((failures > 0 ? 1 : 0))"
