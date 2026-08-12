#!/usr/bin/env bash
# Post-release: verify package on wordpress.org.
# Usage: check-wporg.sh [VERSION]
# Exit 0 = package healthy (update cooldown may WARN)
# Exit 1 = package integrity failure or plugin not hosted on wp.org

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_PATH="${PP_SOURCE_PATH:-${GITHUB_WORKSPACE:-/project}}"
UA="PublishPress-DevWorkspace-WPORG-Check/1.0"

show_help() {
    cat <<EOF
Post-release WordPress.org verification.

Usage: check-wporg.sh [VERSION]

  VERSION     Version to verify. Default: Version header in main plugin file.
  -h, --help  Show help.

Requires the plugin to be hosted on wordpress.org (plugin directory page HTTP 200).
EOF
}

VERSION_ARG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        show_help
        exit 0
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
WARN=0

pass() { PASS=$((PASS + 1)); printf 'PASS  %s — %s\n' "$1" "$2"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s — %s\n' "$1" "$2"; }
warn() { WARN=$((WARN + 1)); printf 'WARN  %s — %s\n' "$1" "$2"; }

is_stable_version() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

extract_header_version() {
    local file="$1"
    [[ -f "$file" ]] || { echo ""; return; }
    sed -nE 's/^[[:space:]]*\*[[:space:]]*Version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.[0-9]+)?).*/\1/p' "$file" | head -1 | tr -d '\r'
}

extract_constant_version() {
    local file="$1"
    local constant="$2"
    [[ -f "$file" && -n "$constant" ]] || { echo ""; return; }
    sed -nE "s/.*define\\('${constant}',[[:space:]]*'([^']+)'\\).*/\\1/p" "$file" | head -1 | tr -d '\r'
}

extract_stable_tag() {
    local file="$1"
    [[ -f "$file" ]] || { echo ""; return; }
    sed -nE 's/^Stable tag:[[:space:]]*(.+)$/\1/p' "$file" | head -1 | tr -d '\r'
}

prior_patch() {
    python3 - "$1" <<'PY'
import sys
v = sys.argv[1].split("-", 1)[0]
parts = v.split(".")
if len(parts) != 3 or not all(p.isdigit() for p in parts):
    print("")
    raise SystemExit(0)
major, minor, patch = map(int, parts)
if patch > 0:
    print(f"{major}.{minor}.{patch - 1}")
elif minor > 0:
    print(f"{major}.{minor - 1}.0")
else:
    print("")
PY
}

http_code() {
    curl -sS -o /dev/null -w '%{http_code}' -A "$UA" -I "$1" || echo "000"
}

PLUGIN_SLUG="$("$SCRIPT_DIR/plugin-slug.sh" "$SOURCE_PATH")"
VERSION_CONSTANT="$("$SCRIPT_DIR/parse-json.sh" "$SOURCE_PATH/composer.json" "extra.version-constant" 2>/dev/null || true)"
MAIN_SOURCE="${SOURCE_PATH}/${PLUGIN_SLUG}.php"

HEADER_VER="$(extract_header_version "$MAIN_SOURCE")"
VERSION="${VERSION_ARG:-$HEADER_VER}"

if [[ -z "$VERSION" ]]; then
    "$SCRIPT_DIR/echo-error.sh" "VERSION required (pass arg or set Version header)."
    exit 1
fi

if ! is_stable_version "$VERSION"; then
    fail "Stable version" "check:wporg requires stable x.y.z, got '${VERSION}'"
    echo "PASS=${PASS} WARN=${WARN} FAIL=${FAIL}"
    exit 1
fi

PAGE_URL="https://wordpress.org/plugins/${PLUGIN_SLUG}/"
PAGE_CODE="$(curl -sS -o /dev/null -w '%{http_code}' -A "$UA" -L "$PAGE_URL" || echo "000")"
if [[ "$PAGE_CODE" != "200" ]]; then
    "$SCRIPT_DIR/echo-error.sh" "Plugin does not appear hosted on wordpress.org (${PAGE_URL} → ${PAGE_CODE}). Skip check:wporg for non-directory plugins."
    exit 1
fi

ZIP_URL="https://downloads.wordpress.org/plugin/${PLUGIN_SLUG}.${VERSION}.zip"
CHECKSUM_URL="https://downloads.wordpress.org/plugin-checksums/${PLUGIN_SLUG}/${VERSION}.json"
UPDATE_URL="https://api.wordpress.org/plugins/update-check/1.1/"

echo "=== check:wporg — ${PLUGIN_SLUG} ${VERSION} ==="
echo

code="$(http_code "$ZIP_URL")"
if [[ "$code" == "200" ]]; then
    pass "ZIP available" "$ZIP_URL ($code)"
else
    fail "ZIP available" "$ZIP_URL ($code)"
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
ZIP_FILE="${TMPDIR}/plugin.zip"

if [[ "$code" == "200" ]]; then
    curl -sS -A "$UA" -L "$ZIP_URL" -o "$ZIP_FILE"
    MAIN_IN_ZIP="${PLUGIN_SLUG}/${PLUGIN_SLUG}.php"
    README_IN_ZIP="${PLUGIN_SLUG}/readme.txt"

    HEADER_ZIP="$(unzip -p "$ZIP_FILE" "$MAIN_IN_ZIP" 2>/dev/null | sed -nE 's/^[[:space:]]*\*[[:space:]]*Version:[[:space:]]*(.+)$/\1/p' | head -1 | tr -d '\r')"
    CONST_ZIP=""
    if [[ -n "$VERSION_CONSTANT" ]]; then
        CONST_ZIP="$(unzip -p "$ZIP_FILE" "$MAIN_IN_ZIP" 2>/dev/null | sed -nE "s/.*define\\('${VERSION_CONSTANT}',[[:space:]]*'([^']+)'\\).*/\\1/p" | head -1 | tr -d '\r')"
    fi
    STABLE_ZIP="$(unzip -p "$ZIP_FILE" "$README_IN_ZIP" 2>/dev/null | sed -nE 's/^Stable tag:[[:space:]]*(.+)$/\1/p' | head -1 | tr -d '\r')"

    if [[ "$HEADER_ZIP" == "$VERSION" ]]; then
        pass "Version header" "$HEADER_ZIP"
    else
        fail "Version header" "expected ${VERSION}, got '${HEADER_ZIP:-missing}'"
    fi

    if [[ -n "$VERSION_CONSTANT" ]]; then
        if [[ "$CONST_ZIP" == "$VERSION" ]]; then
            pass "Version constant" "$CONST_ZIP"
        else
            fail "Version constant" "expected ${VERSION}, got '${CONST_ZIP:-missing}'"
        fi
    fi

    if [[ "$STABLE_ZIP" == "$VERSION" ]]; then
        pass "Stable tag" "$STABLE_ZIP"
    else
        fail "Stable tag" "expected ${VERSION}, got '${STABLE_ZIP:-missing}'"
    fi

    if [[ "$HEADER_ZIP" == *-* ]]; then
        fail "Pre-release in stable ZIP" "header is ${HEADER_ZIP}"
    fi
else
    fail "Version header" "skipped (no ZIP)"
    fail "Version constant" "skipped (no ZIP)"
    fail "Stable tag" "skipped (no ZIP)"
fi

cscode="$(http_code "$CHECKSUM_URL")"
if [[ "$cscode" == "200" ]]; then
    CS_META="$(curl -sS -A "$UA" "$CHECKSUM_URL" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('version',''))
print(len(d.get('files') or {}))
print(d.get('source',''))
")"
    CS_VER="$(echo "$CS_META" | sed -n '1p')"
    CS_FILES="$(echo "$CS_META" | sed -n '2p')"
    CS_SRC="$(echo "$CS_META" | sed -n '3p')"
    if [[ "$CS_VER" == "$VERSION" ]]; then
        pass "Checksums" "${CHECKSUM_URL} (version=${CS_VER}, files=${CS_FILES})"
    else
        fail "Checksums" "JSON version '${CS_VER}' != ${VERSION}"
    fi
    if [[ -n "$CS_SRC" && "$CS_SRC" != *"/tags/${VERSION}"* ]]; then
        warn "Checksums source" "expected tags/${VERSION}, got ${CS_SRC}"
    fi
else
    fail "Checksums" "$CHECKSUM_URL ($cscode)"
fi

PAGE_HTML_FILE="${TMPDIR}/page.html"
curl -sS -A "$UA" -L "$PAGE_URL" -o "$PAGE_HTML_FILE" || true
if grep -Fq "\"softwareVersion\": \"${VERSION}\"" "$PAGE_HTML_FILE"; then
    pass "Plugin page" "softwareVersion=${VERSION}"
elif grep -Fqi "Version <strong>${VERSION}</strong>" "$PAGE_HTML_FILE"; then
    pass "Plugin page" "Version label=${VERSION}"
else
    fail "Plugin page" "did not find Version ${VERSION} on ${PAGE_URL}"
fi

PREV="$(prior_patch "$VERSION")"
OLDER="$(prior_patch "$PREV")"

update_check() {
    local from="$1"
    local payload
    payload="$(python3 - "$from" "$PLUGIN_SLUG" <<'PY'
import json, sys
from_ver, slug = sys.argv[1], sys.argv[2]
plugin_file = f"{slug}/{slug}.php"
print(json.dumps({
  "plugins": {
    plugin_file: {
      "Version": from_ver,
      "Slug": slug,
    }
  },
  "active": [plugin_file],
}))
PY
)"
    curl -sS -A "WordPress/6.8; https://example.test" \
        --data-urlencode "plugins=${payload}" \
        "$UPDATE_URL" || echo "{}"
}

parse_update() {
    python3 - "$PLUGIN_SLUG" <<'PY'
import sys, json
slug = sys.argv[1]
plugin_file = f"{slug}/{slug}.php"
try:
    d = json.load(sys.stdin)
except Exception:
    print("")
    print("")
    raise SystemExit(0)
plugins = d.get("plugins") or {}
p = plugins.get(plugin_file) or {}
print(p.get("new_version", ""))
print(p.get("package", ""))
PY
}

if [[ -n "$PREV" ]]; then
    UC_JSON="$(update_check "$PREV")"
    UC_NEW="$(printf '%s' "$UC_JSON" | parse_update)"
    UC_VER="$(echo "$UC_NEW" | sed -n '1p')"
    UC_PKG="$(echo "$UC_NEW" | sed -n '2p')"

    if [[ "$UC_VER" == "$VERSION" && "$UC_PKG" == *"${PLUGIN_SLUG}.${VERSION}.zip"* ]]; then
        pass "Update-check" "from ${PREV} → ${UC_VER}"
    elif [[ -z "$UC_VER" ]]; then
        if [[ -n "$OLDER" ]]; then
            OLD_JSON="$(update_check "$OLDER")"
            OLD_NEW="$(printf '%s' "$OLD_JSON" | parse_update)"
            OLD_VER="$(echo "$OLD_NEW" | sed -n '1p')"
            OLD_PKG="$(echo "$OLD_NEW" | sed -n '2p')"
            if [[ "$OLD_VER" == "$VERSION" ]]; then
                pass "Update-check" "from ${OLDER} → ${VERSION}"
            elif [[ -n "$OLD_VER" ]]; then
                warn "Update-check" "cooldown: from ${OLDER} still offers ${OLD_VER} (not ${VERSION}). Package: ${OLD_PKG}"
            else
                warn "Update-check" "from ${PREV}: no offer; from ${OLDER}: no offer either"
            fi
        else
            warn "Update-check" "from ${PREV}: no update offered (likely Protect the Shire cooldown)"
        fi
    elif [[ "$UC_VER" != "$VERSION" ]]; then
        warn "Update-check" "from ${PREV} still offers ${UC_VER} (Protect the Shire cooldown?). Package: ${UC_PKG}"
    else
        warn "Update-check" "from ${PREV} → ${UC_VER} but package URL unexpected: ${UC_PKG}"
    fi
else
    warn "Update-check" "could not derive prior version from ${VERSION}"
fi

echo
echo "PASS=${PASS} WARN=${WARN} FAIL=${FAIL}"
if [[ "$FAIL" -gt 0 ]]; then
    "$SCRIPT_DIR/echo-error.sh" "check:wporg failed — package/integrity issue on wordpress.org."
    exit 1
fi
if [[ "$WARN" -gt 0 ]]; then
    "$SCRIPT_DIR/echo-success.sh" "check:wporg: package OK (update cooldown or soft warning)."
    echo "Next: wait ~6h or ask plugins@wordpress.org / #pluginreview to lift hold if urgent."
    exit 0
fi
"$SCRIPT_DIR/echo-success.sh" "check:wporg passed — package and update API agree on ${VERSION}."
exit 0
