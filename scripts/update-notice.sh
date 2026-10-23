#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CHANGELOG_PATH=""
STAMP_PATH=""
FORCE=0
CHANGELOG_SET=0
STAMP_SET=0

show_help() {
    echo "Show dev-workspace changelog entries since the last interactive dev:shell."
    echo "Usage: update-notice.sh [--changelog PATH] [--stamp PATH] [--force]"
    echo ""
    echo "  --changelog PATH  CHANGELOG file (default: package CHANGELOG.md)"
    echo "  --stamp PATH      Last-seen version file (default: CACHE_PATH/.dev_workspace_last_seen_version)"
    echo "  --force           Run even when not a TTY or inside the container (tests)"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            show_help
            exit 0
            ;;
        --changelog)
            CHANGELOG_PATH="$2"
            CHANGELOG_SET=1
            shift 2
            ;;
        --stamp)
            STAMP_PATH="$2"
            STAMP_SET=1
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help >&2
            exit 1
            ;;
    esac
done

if [[ "$CHANGELOG_SET" -eq 1 && "$STAMP_SET" -eq 1 ]]; then
    :
elif [[ "$CHANGELOG_SET" -eq 1 || "$STAMP_SET" -eq 1 ]]; then
    echo "update-notice.sh: pass both --changelog and --stamp, or neither." >&2
    exit 1
else
    source "$SCRIPT_DIR/env-bootstrap.sh"
    CHANGELOG_PATH="${DEV_WORKSPACE_DIR}/CHANGELOG.md"
    STAMP_PATH="${CACHE_PATH}/.dev_workspace_last_seen_version"
fi

if [[ "$FORCE" -eq 0 ]]; then
    if [[ "${INSIDE_DEV_CONTAINER:-}" == "true" ]]; then
        exit 0
    fi
    if [[ ! -t 1 ]]; then
        exit 0
    fi
fi

if [[ ! -f "$CHANGELOG_PATH" ]]; then
    exit 0
fi

version_gt() {
    local a="$1"
    local b="$2"
    [[ "$a" != "$b" && "$(printf '%s\n' "$a" "$b" | sort -V | tail -1)" == "$a" ]]
}

read_current_version() {
    awk '/^\[[0-9]/ {
        line = $0
        sub(/^\[/, "", line)
        sub(/\].*$/, "", line)
        print line
        exit
    }' "$CHANGELOG_PATH"
}

section_in_range() {
    local prev="$1"
    local current="$2"
    local section="$3"

    if [[ -z "$prev" ]]; then
        [[ "$section" == "$current" ]]
        return
    fi

    version_gt "$section" "$prev" && ! version_gt "$section" "$current"
}

CURRENT="$(read_current_version)"
if [[ -z "$CURRENT" ]]; then
    exit 0
fi

PREV=""
if [[ -f "$STAMP_PATH" ]]; then
    PREV="$(tr -d '[:space:]' < "$STAMP_PATH")"
fi

SHOULD_PRINT=0
if [[ -z "$PREV" ]]; then
    SHOULD_PRINT=1
elif version_gt "$CURRENT" "$PREV"; then
    SHOULD_PRINT=1
fi

if [[ "$SHOULD_PRINT" -eq 1 ]]; then
    separator="$("$SCRIPT_DIR/echo-separator.sh" 1)"
    if [[ -z "$PREV" ]]; then
        "$SCRIPT_DIR/echo-title.sh" "Dev-workspace ${CURRENT} (previous version unknown)"
        echo ""
        echo "Showing the current release only. See CHANGELOG.md for full history."
    else
        "$SCRIPT_DIR/echo-title.sh" "Dev-workspace updated: ${PREV} -> ${CURRENT}"
    fi
    echo ""

    in_section=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^\[([0-9][^\]]*)\] ]]; then
            section_ver="${BASH_REMATCH[1]}"
            if section_in_range "$PREV" "$CURRENT" "$section_ver"; then
                in_section=1
                echo "$line"
            else
                in_section=0
            fi
        elif [[ "$in_section" -eq 1 ]]; then
            echo "$line"
        fi
    done < "$CHANGELOG_PATH"

    echo ""
    echo "${separator}"
    echo ""
fi

mkdir -p "$(dirname "$STAMP_PATH")"
printf '%s\n' "$CURRENT" > "$STAMP_PATH"
