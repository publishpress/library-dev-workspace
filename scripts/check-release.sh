#!/usr/bin/env bash
# Pre-release gate: stable version consistency across source + dist.
# Usage:
#   check-release.sh [--if-stable] [--allow-published] [VERSION]
# Exit 0 = OK (or skipped via --if-stable on prerelease)
# Exit 1 = FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_PATH="${PP_SOURCE_PATH:-${GITHUB_WORKSPACE:-/project}}"
IF_STABLE=0
ALLOW_PUBLISHED=0
VERSION_ARG=""
start_time=$(date +%s)

show_help() {
    cat <<EOF
Pre-release version integrity check (stable releases only).

Usage: check-release.sh [--if-stable] [--allow-published] [VERSION]

  VERSION             Expected version. Default: Version header in main plugin file.
  --if-stable         If current version is not stable (beta/rc/alpha), skip and exit 0.
                      Used by composer build so beta packages still pack.
  --allow-published   Do not fail when this version is already on wordpress.org.
  -h, --help          Show help.

Checks (all must pass for a stable release):
  - Version is stable (x.y.z only)
  - Header Version, version constant, readme Stable tag, CHANGELOG agree
  - package.json "version" (only if the file exists and defines version)
  - dist/ ZIP and/or unpacked folder match source
  - Version is not already published on wordpress.org (when the plugin is hosted there)
EOF
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
        VERSION_ARG="$1"
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

PLUGIN_SLUG="$("$SCRIPT_DIR/plugin-slug.sh" "$SOURCE_PATH")"
PLUGIN_FOLDER="$("$SCRIPT_DIR/plugin-folder.sh" "$SOURCE_PATH")"
VERSION_CONSTANT="$("$SCRIPT_DIR/parse-json.sh" "$SOURCE_PATH/composer.json" "extra.version-constant" 2>/dev/null || true)"

MAIN_SOURCE="${SOURCE_PATH}/${PLUGIN_SLUG}.php"
README_SOURCE="${SOURCE_PATH}/readme.txt"
PACKAGE_JSON="${SOURCE_PATH}/package.json"
CHANGELOG="${SOURCE_PATH}/CHANGELOG.md"
DIST_DIR="${SOURCE_PATH}/dist/${PLUGIN_FOLDER}"
DIST_MAIN="${DIST_DIR}/${PLUGIN_SLUG}.php"
DIST_README="${DIST_DIR}/readme.txt"

if [[ ! -f "$MAIN_SOURCE" ]]; then
    "$SCRIPT_DIR/echo-error.sh" "Main plugin file not found: ${MAIN_SOURCE}"
    finish_failure "check:release could not find the main plugin file."
fi

HEADER_VER="$(extract_header_version "$MAIN_SOURCE")"
if [[ -z "$HEADER_VER" ]]; then
    "$SCRIPT_DIR/echo-error.sh" "Could not read Version header from ${MAIN_SOURCE}"
    finish_failure "check:release could not read the Version header."
fi

VERSION="${VERSION_ARG:-$HEADER_VER}"

"$SCRIPT_DIR/echo-command-header.sh" "Running check:release for ${PLUGIN_SLUG} ${VERSION}"
"$SCRIPT_DIR/echo-step.sh" "Source path: ${SOURCE_PATH}"

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

"$SCRIPT_DIR/echo-step.sh" "Checking source Version header"
if [[ "$HEADER_VER" == "$VERSION" ]]; then
    pass "Source Version header" "$HEADER_VER"
else
    fail "Source Version header" "expected ${VERSION}, got '${HEADER_VER}'"
fi

"$SCRIPT_DIR/echo-step.sh" "Checking source version constant"
if [[ -z "$VERSION_CONSTANT" ]]; then
    fail "Version constant" "extra.version-constant missing in composer.json"
else
    CONST_VER="$(extract_constant_version "$MAIN_SOURCE" "$VERSION_CONSTANT")"
    if [[ "$CONST_VER" == "$VERSION" ]]; then
        pass "Source version constant" "${VERSION_CONSTANT}=${CONST_VER}"
    else
        fail "Source version constant" "expected ${VERSION}, got '${CONST_VER:-missing}' (${VERSION_CONSTANT})"
    fi
fi

"$SCRIPT_DIR/echo-step.sh" "Checking source Stable tag"
if [[ ! -f "$README_SOURCE" ]]; then
    fail "Source Stable tag" "readme.txt not found"
else
    STABLE_TAG="$(extract_stable_tag "$README_SOURCE")"
    if [[ "$STABLE_TAG" == "$VERSION" ]]; then
        pass "Source Stable tag" "$STABLE_TAG"
    else
        fail "Source Stable tag" "expected ${VERSION}, got '${STABLE_TAG:-missing}'"
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

"$SCRIPT_DIR/echo-step.sh" "Checking CHANGELOG.md section"
if [[ ! -f "$CHANGELOG" ]]; then
    fail "CHANGELOG" "CHANGELOG.md not found"
else
    if grep -Eq "^\[${VERSION}\]" "$CHANGELOG"; then
        pass "CHANGELOG section" "[${VERSION}] present"
    else
        fail "CHANGELOG section" "missing [${VERSION}] heading in CHANGELOG.md"
    fi
fi

"$SCRIPT_DIR/echo-command-header.sh" "Checking dist package version metadata"
ZIP_NAME="$("$SCRIPT_DIR/plugin-zipfile.sh" "$SOURCE_PATH")"
ZIP_PATH="${SOURCE_PATH}/dist/${ZIP_NAME}"
HAS_DIST=0

if [[ -f "$ZIP_PATH" ]]; then
    HAS_DIST=1
    "$SCRIPT_DIR/echo-step.sh" "Inspecting dist ZIP ${ZIP_NAME}"
    TMPZIP="$(mktemp -d)"
    unzip -q "$ZIP_PATH" -d "$TMPZIP"
    ZIP_MAIN="${TMPZIP}/${PLUGIN_FOLDER}/${PLUGIN_SLUG}.php"
    ZIP_README="${TMPZIP}/${PLUGIN_FOLDER}/readme.txt"
    ZIP_HEADER="$(extract_header_version "$ZIP_MAIN")"
    ZIP_CONST="$(extract_constant_version "$ZIP_MAIN" "$VERSION_CONSTANT")"
    ZIP_STABLE="$(extract_stable_tag "$ZIP_README")"

    if [[ "$ZIP_HEADER" == "$VERSION" ]]; then
        pass "Dist ZIP Version header" "$ZIP_HEADER"
    else
        fail "Dist ZIP Version header" "expected ${VERSION}, got '${ZIP_HEADER:-missing}' in ${ZIP_NAME}"
    fi
    if [[ -n "$VERSION_CONSTANT" ]]; then
        if [[ "$ZIP_CONST" == "$VERSION" ]]; then
            pass "Dist ZIP version constant" "$ZIP_CONST"
        else
            fail "Dist ZIP version constant" "expected ${VERSION}, got '${ZIP_CONST:-missing}'"
        fi
    fi
    if [[ "$ZIP_STABLE" == "$VERSION" ]]; then
        pass "Dist ZIP Stable tag" "$ZIP_STABLE"
    else
        fail "Dist ZIP Stable tag" "expected ${VERSION}, got '${ZIP_STABLE:-missing}'"
    fi
    rm -rf "$TMPZIP"
elif [[ -f "$DIST_MAIN" ]]; then
    HAS_DIST=1
    "$SCRIPT_DIR/echo-step.sh" "Inspecting dist directory ${DIST_DIR}"
    DIR_HEADER="$(extract_header_version "$DIST_MAIN")"
    DIR_CONST="$(extract_constant_version "$DIST_MAIN" "$VERSION_CONSTANT")"
    DIR_STABLE="$(extract_stable_tag "$DIST_README")"

    if [[ "$DIR_HEADER" == "$VERSION" ]]; then
        pass "Dist dir Version header" "$DIR_HEADER"
    else
        fail "Dist dir Version header" "expected ${VERSION}, got '${DIR_HEADER:-missing}'"
    fi
    if [[ -n "$VERSION_CONSTANT" ]]; then
        if [[ "$DIR_CONST" == "$VERSION" ]]; then
            pass "Dist dir version constant" "$DIR_CONST"
        else
            fail "Dist dir version constant" "expected ${VERSION}, got '${DIR_CONST:-missing}'"
        fi
    fi
    if [[ "$DIR_STABLE" == "$VERSION" ]]; then
        pass "Dist dir Stable tag" "$DIR_STABLE"
    else
        fail "Dist dir Stable tag" "expected ${VERSION}, got '${DIR_STABLE:-missing}'"
    fi
fi

if [[ "$HAS_DIST" -eq 0 ]]; then
    fail "Dist package" "No dist ZIP (${ZIP_PATH}) or unpacked dir (${DIST_DIR}). Run composer build / pack:zip first"
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
"$SCRIPT_DIR/echo-success.sh" "check:release passed for ${VERSION}"
finish_success
