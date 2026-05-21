#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Run PHP compatibility checks with PHPCS across configured PHP versions."
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --simple-versions=<csv>       Optional. Comma-separated PHP versions for main plugin file."
    echo "  --full-versions=<csv>         Optional. Comma-separated PHP versions for project root."
    echo "  -h, --help                    Show this help message."
    echo ""
    echo "Environment:"
    echo "  PP_PLUGIN_SLUG                Plugin slug (Composer DevWorkspace plugin; from extra.plugin-slug)."
    echo "                                If unset, falls back to extra.plugin-slug via plugin-slug.sh."
    echo ""
    echo "Example:"
    echo "  $0 --simple-versions='5.6,7.2' --full-versions='7.4,8.0,8.1,8.2,8.3,8.4,8.5'"
}

simple_version_list=""
full_version_list=""

while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
        show_help
        exit 0
        ;;
    --simple-versions=*)
        simple_version_list="${1#*=}"
        shift
        ;;
    --simple-versions | --full-versions)
        "$SCRIPT_DIR/echo-error.sh" "Use --${1#--}=<csv> (e.g. --${1#--}='5.6,7.2')"
        show_help
        exit 1
        ;;
    --full-versions=*)
        full_version_list="${1#*=}"
        shift
        ;;
    *)
        "$SCRIPT_DIR/echo-error.sh" "Unknown argument: $1"
        show_help
        exit 1
        ;;
    esac
done

plugin_slug="${PP_PLUGIN_SLUG:-}"
if [ -z "$plugin_slug" ]; then
    plugin_slug="$("$SCRIPT_DIR/plugin-slug.sh")"
fi
plugin_file="./${plugin_slug}.php"

if [ -z "$plugin_slug" ]; then
    "$SCRIPT_DIR/echo-error.sh" "Plugin slug not found. Set PP_PLUGIN_SLUG or extra.plugin-slug in composer.json."
    show_help
    exit 1
fi

if [ -z "$simple_version_list" ] && [ -z "$full_version_list" ]; then
    "$SCRIPT_DIR/echo-error.sh" "No checks to run. Pass --simple-versions and/or --full-versions."
    show_help
    exit 1
fi

run_check() {
    local version="$1"
    local path="$2"

    echo "Running PHP compatibility check for ${path} (PHP ${version})"
    phpcs --standard=.phpcs-php-compatibility.xml \
        --runtime-set testVersion "${version}" "${path}"
}

run_checks_for_csv() {
    local csv="$1"
    local path="$2"
    local php_version

    IFS=',' read -r -a versions <<< "$csv"
    for php_version in "${versions[@]}"; do
        php_version="${php_version#"${php_version%%[![:space:]]*}"}"
        php_version="${php_version%"${php_version##*[![:space:]]}"}"
        if [ -n "$php_version" ]; then
            run_check "$php_version" "$path"
        fi
    done
}

if [ -n "$simple_version_list" ]; then
    if [ ! -f "$plugin_file" ]; then
        "$SCRIPT_DIR/echo-error.sh" "Plugin file not found: ${plugin_file}"
        exit 1
    fi

    run_checks_for_csv "$simple_version_list" "$plugin_file"
fi

if [ -n "$full_version_list" ]; then
    run_checks_for_csv "$full_version_list" "./"
fi
