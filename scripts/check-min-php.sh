#!/usr/bin/env bash
# Minimum PHP version gate: readme.txt, plugin header, main file guard, composer.json.
# Usage:
#   check-min-php.sh [--version=X.Y] [PATH]
# Exit 0 = OK
# Exit 1 = FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

EXPECTED="${PP_MIN_PHP_VERSION:-8.2}"
CHECK_PATH="."

show_help() {
    cat <<EOF
Verify the plugin declares and enforces the minimum PHP version.

Usage: check-min-php.sh [--version=X.Y] [PATH]

  PATH             Plugin folder (must contain composer.json and the main plugin file).
                   Default: current directory.
  --version=X.Y    Expected minimum PHP version. Default: \$PP_MIN_PHP_VERSION or 8.2.
  -h, --help       Show help.

Checks (all must match the expected version):
  - readme.txt "Requires PHP:"
  - Main plugin file header "Requires PHP:"
  - Main plugin file guard: version_compare(phpversion()|PHP_VERSION, <min>, '<')
    with <min> as a literal, \$variable, or constant; or PHP_VERSION_ID < XXYYZZ
  - composer.json require.php (">=X.Y" or "^X.Y")
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        show_help
        exit 0
        ;;
    --version=*)
        EXPECTED="${1#*=}"
        shift
        ;;
    -*)
        "$SCRIPT_DIR/echo-error.sh" "Unknown option: $1"
        show_help
        exit 1
        ;;
    *)
        CHECK_PATH="$1"
        shift
        ;;
    esac
done

PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    "$SCRIPT_DIR/echo-success.sh" "${1}: ${2}"
}

fail() {
    FAIL=$((FAIL + 1))
    "$SCRIPT_DIR/echo-error.sh" "${1}: ${2}"
}

# 8.2.0 and 8.2 are equivalent.
normalize_version() {
    local version="$1"
    if [[ "$version" =~ ^([0-9]+\.[0-9]+)\.0$ ]]; then
        version="${BASH_REMATCH[1]}"
    fi
    echo "$version"
}

php_version_id_to_version() {
    local id="$1"
    normalize_version "$((id / 10000)).$(((id / 100) % 100)).$((id % 100))"
}

extract_requires_php() {
    local file="$1"
    sed -nE 's/^[[:space:]*]*Requires PHP:[[:space:]]*([^[:space:]]+).*/\1/p' "$file" | head -1 | tr -d '\r'
}

# Resolve the min-version argument of a version_compare() guard to a version string.
resolve_guard_arg() {
    local file="$1"
    local arg="$2"
    local name

    if [[ "$arg" =~ ^[\'\"]([0-9.]+)[\'\"]$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi

    if [[ "$arg" =~ ^\$([A-Za-z_][A-Za-z0-9_]*)$ ]]; then
        name="${BASH_REMATCH[1]}"
        sed -nE "s/.*\\\$${name}[[:space:]]*=[[:space:]]*['\"]([0-9.]+)['\"].*/\1/p" "$file" | head -1
        return
    fi

    if [[ "$arg" =~ ^([A-Za-z_\\]+::)?([A-Za-z_][A-Za-z0-9_]*)$ ]]; then
        name="${BASH_REMATCH[2]}"
        {
            sed -nE "s/.*const[[:space:]]+${name}[[:space:]]*=[[:space:]]*['\"]([0-9.]+)['\"].*/\1/p" "$file"
            sed -nE "s/.*define\([[:space:]]*['\"]${name}['\"][[:space:]]*,[[:space:]]*['\"]([0-9.]+)['\"].*/\1/p" "$file"
        } | head -1
    fi
}

# Print one guard version per line found in the main plugin file.
extract_guard_versions() {
    local file="$1"
    local match arg version

    while IFS= read -r match; do
        arg="$(sed -nE 's/.*,[[:space:]]*([^,)[:space:]]+)[[:space:]]*$/\1/p' <<< "$match")"
        version="$(resolve_guard_arg "$file" "$arg")"
        echo "${version:-unresolved ${arg}}"
    done < <(grep -oE "version_compare\([[:space:]]*(phpversion\(\)|PHP_VERSION)[[:space:]]*,[[:space:]]*[^,)]+" "$file" || true)

    while IFS= read -r match; do
        php_version_id_to_version "$(grep -oE '[0-9]+$' <<< "$match")"
    done < <(grep -oE "PHP_VERSION_ID[[:space:]]*(<|>=)[[:space:]]*[0-9]{5,6}" "$file" || true)
}

check_requires_php() {
    local label="$1"
    local file="$2"
    local found

    if [[ ! -f "$file" ]]; then
        fail "$label" "$(basename "$file") not found"
        return
    fi

    found="$(extract_requires_php "$file")"
    if [[ -n "$found" && "$(normalize_version "$found")" == "$EXPECTED" ]]; then
        pass "$label" "$found"
    else
        fail "$label" "expected ${EXPECTED}, got '${found:-missing}'"
    fi
}

EXPECTED="$(normalize_version "$EXPECTED")"

if [[ ! -f "${CHECK_PATH}/composer.json" ]]; then
    "$SCRIPT_DIR/echo-error.sh" "composer.json not found in ${CHECK_PATH}"
    exit 1
fi

PLUGIN_SLUG="$("$SCRIPT_DIR/plugin-slug.sh" "$CHECK_PATH")"
MAIN_FILE="${CHECK_PATH}/${PLUGIN_SLUG}.php"

"$SCRIPT_DIR/echo-command-header.sh" "Checking minimum PHP version ${EXPECTED} for ${PLUGIN_SLUG}"

"$SCRIPT_DIR/echo-step.sh" "Checking readme.txt Requires PHP"
check_requires_php "readme.txt Requires PHP" "${CHECK_PATH}/readme.txt"

"$SCRIPT_DIR/echo-step.sh" "Checking plugin header Requires PHP"
check_requires_php "Plugin header Requires PHP" "$MAIN_FILE"

"$SCRIPT_DIR/echo-step.sh" "Checking main plugin file PHP guard"
if [[ ! -f "$MAIN_FILE" ]]; then
    fail "Main plugin file PHP guard" "$(basename "$MAIN_FILE") not found"
else
    mapfile -t GUARD_VERSIONS < <(extract_guard_versions "$MAIN_FILE")
    guard_ok=0
    for guard_version in "${GUARD_VERSIONS[@]}"; do
        if [[ "$(normalize_version "$guard_version")" == "$EXPECTED" ]]; then
            guard_ok=1
        fi
    done

    if [[ "${#GUARD_VERSIONS[@]}" -eq 0 ]]; then
        fail "Main plugin file PHP guard" "no version_compare(phpversion()|PHP_VERSION, ...) or PHP_VERSION_ID guard found"
    elif [[ "$guard_ok" -eq 1 ]]; then
        pass "Main plugin file PHP guard" "$EXPECTED"
    else
        fail "Main plugin file PHP guard" "expected ${EXPECTED}, got '$(IFS=,; echo "${GUARD_VERSIONS[*]}")'"
    fi
fi

"$SCRIPT_DIR/echo-step.sh" "Checking composer.json require.php"
COMPOSER_PHP="$(jq -r '.require.php // empty' "${CHECK_PATH}/composer.json")"
# First token of the first alternative, e.g. ">=8.2 <9.0 || ^9" -> ">=8.2".
COMPOSER_PHP_MIN="$(sed -E 's/\|.*//; s/^[[:space:]]+//; s/[[:space:],].*//' <<< "$COMPOSER_PHP")"
if [[ "$COMPOSER_PHP_MIN" =~ ^(\>=|\^)v?([0-9]+(\.[0-9]+){0,2})$ ]] \
    && [[ "$(normalize_version "${BASH_REMATCH[2]}")" == "$EXPECTED" ]]; then
    pass "composer.json require.php" "$COMPOSER_PHP"
else
    fail "composer.json require.php" "expected >=${EXPECTED}, got '${COMPOSER_PHP:-missing}'"
fi

"$SCRIPT_DIR/echo-step.sh" "Summary: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
    "$SCRIPT_DIR/echo-error.sh" "check:min-php failed — minimum PHP version must be ${EXPECTED} everywhere."
    exit 1
fi
"$SCRIPT_DIR/echo-success.sh" "check:min-php passed for PHP ${EXPECTED}"
