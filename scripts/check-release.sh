#!/usr/bin/env bash
# Pre-release gate: stable version consistency for a plugin folder.
# Usage:
#   check-release.sh [--if-stable] [--allow-published] [PATH] [VERSION]
# Exit 0 = OK (or skipped via --if-stable on prerelease)
# Exit 1 = FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEFAULT_PATH="${PP_SOURCE_PATH:-${GITHUB_WORKSPACE:-/project}}"
CHECK_PATH=""
IF_STABLE=0
ALLOW_PUBLISHED=0
VERSION_ARG=""
POSITIONALS=()
start_time=$(date +%s)

show_help() {
    cat <<EOF
Pre-release version integrity check (stable releases only).

Usage: check-release.sh [--if-stable] [--allow-published] [PATH] [VERSION]

  PATH                Plugin folder to inspect (must contain composer.json and the
                      main plugin PHP file). Default: project root
                      (${DEFAULT_PATH}).
  VERSION             Expected version. Default: Version header in main plugin file.
  --if-stable         If current version is not stable (beta/rc/alpha), skip and exit 0.
                      Used by composer build so beta packages still pack.
  --allow-published   Do not fail when this version is already on wordpress.org.
  -h, --help          Show help.

  A single positional is treated as VERSION when it matches x.y.z[(-alpha|-beta|-rc).N],
  otherwise as PATH. Two positionals are PATH then VERSION.

Checks (all must pass for a stable release):
  - Version is stable (x.y.z only)
  - Header Version, version constant, and readme Stable tag agree
  - package.json "version" (only if the file exists and defines version)
  - CHANGELOG.md section (only if CHANGELOG.md exists)
  - Version is not already published on wordpress.org (when the plugin is hosted there)
EOF
}

is_version_string() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.[0-9]+)?$ ]]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        show_help
        exit 0
        ;;
    --if-stable)
        IF_STABLE=1
        shift
        ;;
    --allow-published)
        ALLOW_PUBLISHED=1
        shift
        ;;
    -*)
        "$SCRIPT_DIR/echo-error.sh" "Unknown option: $1"
        exit 1
        ;;
    *)
        POSITIONALS+=("$1")
        shift
        ;;
    esac
done

case "${#POSITIONALS[@]}" in
0) ;;
1)
    if is_version_string "${POSITIONALS[0]}"; then
        VERSION_ARG="${POSITIONALS[0]}"
    else
        CHECK_PATH="${POSITIONALS[0]}"
    fi
    ;;
2)
    CHECK_PATH="${POSITIONALS[0]}"
    VERSION_ARG="${POSITIONALS[1]}"
    ;;
*)
    "$SCRIPT_DIR/echo-error.sh" "Too many arguments. Usage: check-release.sh [options] [PATH] [VERSION]"
    exit 1
    ;;
esac

if [[ -z "$CHECK_PATH" ]]; then
    CHECK_PATH="$DEFAULT_PATH"
fi

# Resolve relative paths against the default project root (container cwd is usually /project).
if [[ "$CHECK_PATH" != /* ]]; then
    CHECK_PATH="${DEFAULT_PATH}/${CHECK_PATH}"
fi

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

finish_success() {
    "$SCRIPT_DIR/echo-separator.sh"
    "$SCRIPT_DIR/show-time.sh" "${start_time}"
    echo ""
    echo "🎉" " Executed successfully!"
    echo ""
    exit 0
}

finish_failure() {
    local message="$1"
    "$SCRIPT_DIR/echo-separator.sh"
    "$SCRIPT_DIR/show-time.sh" "${start_time}"
    echo ""
    echo "⚠️  Error: ${message}"
    echo ""
    exit 1
}

is_stable_version() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

extract_header_version() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo ""
        return
    fi
    sed -nE 's/^[[:space:]]*\*[[:space:]]*Version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.[0-9]+)?).*/\1/p' "$file" | head -1 | tr -d '\r'
}

extract_constant_version() {
    local file="$1"
    local constant="$2"
    if [[ ! -f "$file" || -z "$constant" ]]; then
        echo ""
        return
    fi
    sed -nE "s/.*define\\('${constant}',[[:space:]]*'([^']+)'\\).*/\\1/p" "$file" | head -1 | tr -d '\r'
}

extract_stable_tag() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo ""
        return
    fi
    sed -nE 's/^Stable tag:[[:space:]]*(.+)$/\1/p' "$file" | head -1 | tr -d '\r'
}

if [[ ! -d "$CHECK_PATH" ]]; then
    "$SCRIPT_DIR/echo-error.sh" "Path not found: ${CHECK_PATH}"
    finish_failure "check:release could not find the target path."
fi

# Metadata (slug / version-constant) comes from composer.json in the check path.
if [[ ! -f "${CHECK_PATH}/composer.json" ]]; then
    "$SCRIPT_DIR/echo-error.sh" "composer.json not found in ${CHECK_PATH}"
    finish_failure "check:release requires composer.json in the target path."
fi

PLUGIN_SLUG="$("$SCRIPT_DIR/plugin-slug.sh" "$CHECK_PATH")"
VERSION_CONSTANT="$("$SCRIPT_DIR/parse-json.sh" "$CHECK_PATH/composer.json" "extra.version-constant" 2>/dev/null || true)"

MAIN_FILE="${CHECK_PATH}/${PLUGIN_SLUG}.php"
README_FILE="${CHECK_PATH}/readme.txt"
PACKAGE_JSON="${CHECK_PATH}/package.json"
CHANGELOG="${CHECK_PATH}/CHANGELOG.md"

if [[ ! -f "$MAIN_FILE" ]]; then
    "$SCRIPT_DIR/echo-error.sh" "Main plugin file not found: ${MAIN_FILE}"
    finish_failure "check:release could not find the main plugin file."
fi

HEADER_VER="$(extract_header_version "$MAIN_FILE")"
if [[ -z "$HEADER_VER" ]]; then
    "$SCRIPT_DIR/echo-error.sh" "Could not read Version header from ${MAIN_FILE}"
    finish_failure "check:release could not read the Version header."
fi

VERSION="${VERSION_ARG:-$HEADER_VER}"

"$SCRIPT_DIR/echo-command-header.sh" "Running check:release for ${PLUGIN_SLUG} ${VERSION}"
"$SCRIPT_DIR/echo-step.sh" "Check path: ${CHECK_PATH}"

if ! is_stable_version "$VERSION"; then
    if [[ "$IF_STABLE" -eq 1 ]]; then
        "$SCRIPT_DIR/echo-step.sh" "Skipping check:release — ${VERSION} is not a stable release (--if-stable)"
        finish_success
    fi
    fail "Stable version" "Refusing non-stable version '${VERSION}'. Use x.y.z only"
    finish_failure "check:release failed — version must be stable x.y.z."
fi

"$SCRIPT_DIR/echo-step.sh" "Checking version is stable"
pass "Stable version" "$VERSION"

"$SCRIPT_DIR/echo-step.sh" "Checking Version header"
if [[ "$HEADER_VER" == "$VERSION" ]]; then
    pass "Version header" "$HEADER_VER"
else
    fail "Version header" "expected ${VERSION}, got '${HEADER_VER}'"
fi

"$SCRIPT_DIR/echo-step.sh" "Checking version constant"
if [[ -z "$VERSION_CONSTANT" ]]; then
    fail "Version constant" "extra.version-constant missing in composer.json"
else
    CONST_VER="$(extract_constant_version "$MAIN_FILE" "$VERSION_CONSTANT")"
    if [[ "$CONST_VER" == "$VERSION" ]]; then
        pass "Version constant" "${VERSION_CONSTANT}=${CONST_VER}"
    else
        fail "Version constant" "expected ${VERSION}, got '${CONST_VER:-missing}' (${VERSION_CONSTANT})"
    fi
fi

"$SCRIPT_DIR/echo-step.sh" "Checking Stable tag"
if [[ ! -f "$README_FILE" ]]; then
    fail "Stable tag" "readme.txt not found"
else
    STABLE_TAG="$(extract_stable_tag "$README_FILE")"
    if [[ "$STABLE_TAG" == "$VERSION" ]]; then
        pass "Stable tag" "$STABLE_TAG"
    else
        fail "Stable tag" "expected ${VERSION}, got '${STABLE_TAG:-missing}'"
    fi
fi

"$SCRIPT_DIR/echo-step.sh" "Checking package.json version (optional)"
if [[ ! -f "$PACKAGE_JSON" ]]; then
    pass "package.json" "absent — skipped"
else
    PKG_VER="$(jq -r 'if has("version") then .version else empty end' "$PACKAGE_JSON" 2>/dev/null || true)"
    if [[ -z "$PKG_VER" || "$PKG_VER" == "null" ]]; then
        pass "package.json version" "no version field — skipped"
    elif [[ "$PKG_VER" == "$VERSION" ]]; then
        pass "package.json version" "$PKG_VER"
    else
        fail "package.json version" "expected ${VERSION}, got '${PKG_VER}'"
    fi
fi

"$SCRIPT_DIR/echo-step.sh" "Checking CHANGELOG.md section (optional)"
if [[ ! -f "$CHANGELOG" ]]; then
    pass "CHANGELOG" "absent — skipped"
else
    # Accept Keep a Changelog headings (`## [1.0.0]`) and bare `[1.0.0]` lines.
    if grep -Eq "^#{0,3}[[:space:]]*\[${VERSION}\]" "$CHANGELOG"; then
        pass "CHANGELOG section" "[${VERSION}] present"
    else
        fail "CHANGELOG section" "missing [${VERSION}] heading in CHANGELOG.md"
    fi
fi

"$SCRIPT_DIR/echo-command-header.sh" "Checking WordPress.org publication status"
UA="PublishPress-DevWorkspace-Release-Check/1.0"
"$SCRIPT_DIR/echo-step.sh" "Looking up wordpress.org/plugins/${PLUGIN_SLUG}/"
PAGE_CODE="$(curl -sS -o /dev/null -w '%{http_code}' -A "$UA" -L "https://wordpress.org/plugins/${PLUGIN_SLUG}/" || echo "000")"
if [[ "$PAGE_CODE" == "200" ]]; then
    ZIP_WPORG="https://downloads.wordpress.org/plugin/${PLUGIN_SLUG}.${VERSION}.zip"
    CS_WPORG="https://downloads.wordpress.org/plugin-checksums/${PLUGIN_SLUG}/${VERSION}.json"
    "$SCRIPT_DIR/echo-step.sh" "Checking whether ${VERSION} is already published"
    WZIP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' -A "$UA" -I "$ZIP_WPORG" || echo "000")"
    WCS_CODE="$(curl -sS -o /dev/null -w '%{http_code}' -A "$UA" -I "$CS_WPORG" || echo "000")"
    if [[ "$WZIP_CODE" == "200" || "$WCS_CODE" == "200" ]]; then
        if [[ "$ALLOW_PUBLISHED" -eq 1 ]]; then
            pass "WordPress.org not published" "already live but --allow-published set (${VERSION})"
        else
            fail "WordPress.org not published" "${VERSION} already exists on wordpress.org (ZIP ${WZIP_CODE}, checksums ${WCS_CODE}). Bump version or pass --allow-published"
        fi
    else
        pass "WordPress.org not published" "${VERSION} not found on downloads.wordpress.org"
    fi
else
    pass "WordPress.org hosting" "plugin page not found for slug ${PLUGIN_SLUG} (${PAGE_CODE}) — skipping published check"
fi

"$SCRIPT_DIR/echo-step.sh" "Summary: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
    finish_failure "check:release failed — fix version consistency before releasing."
fi
"$SCRIPT_DIR/echo-success.sh" "check:release passed for ${VERSION} (${CHECK_PATH})"
finish_success
