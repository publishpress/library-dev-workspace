#!/usr/bin/env bash
# Stop a Weblate sync when the Cloudflare Access service token is missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Stop a Weblate translate command when the Cloudflare Access token is missing."
    echo "Usage: require-weblate-access.sh <command> [args...]"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_help
    exit 0
fi

contacts_weblate() {
    local joined=" $* "
    if [[ "$joined" == *"translate-locales.sh"* ]]; then
        return 0
    fi
    if [[ "$joined" != *"publishpress-translate"* ]]; then
        return 1
    fi
    case "$joined" in
        *--repair-plurals*|*--clean-po*|*--sync-files*|*--audit*|*--dry-run*)
            return 1
            ;;
    esac
    return 0
}

if ! contacts_weblate "$@"; then
    exit 0
fi

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

url="${WEBLATE_API_URL:-}"
if [[ -z "$(trim "$url")" ]]; then
    url="https://weblate.publishpress.com/api/"
fi

host="${url#*://}"
host="${host%%/*}"
host="${host%%:*}"
host="${host,,}"

if [[ "$host" != "weblate.publishpress.com" ]]; then
    exit 0
fi

access_id="$(trim "${CF_ACCESS_CLIENT_ID:-}")"
access_secret="$(trim "${CF_ACCESS_CLIENT_SECRET:-}")"

if [[ -n "$access_id" && -n "$access_secret" ]]; then
    exit 0
fi

"$SCRIPT_DIR/echo-error.sh" "Cloudflare Access blocks Weblate. Set CF_ACCESS_CLIENT_ID and CF_ACCESS_CLIENT_SECRET in the plugin .env file."
exit 1
