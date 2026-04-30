#!/usr/bin/env bash
set -euo pipefail

show_help() {
    echo "Usage: translate-json.sh"
    echo ""
    echo "Example:"
    echo "translate-json.sh"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

if [[ "${GENERATE_TRANSLATION_JSON:-}" != "1" && "${GENERATE_TRANSLATION_JSON:-}" != "true" ]]; then
    $SCRIPT_DIR/echo-success.sh "Skipping JSON translation generation (set GENERATE_TRANSLATION_JSON=1 in .env to enable)"
    exit 0
fi

BASE_DIR="/project"
PLUGIN_SLUG="$("$SCRIPT_DIR/plugin-slug.sh")"

read -r -a LOCALES <<< "${LANG_LOCALES:-}"
TOTAL_LOCALES="${#LOCALES[@]}"

if [ "${TOTAL_LOCALES}" -eq 0 ]; then
    $SCRIPT_DIR/echo-success.sh "No locales configured in LANG_LOCALES. Nothing to generate."
    exit 0
fi

echo ""
$SCRIPT_DIR/echo-title.sh "PublishPress Translation: JSON Generation for Plugin"
echo ""
echo "Plugin   : ${PLUGIN_SLUG}"
echo "Locales  : ${TOTAL_LOCALES} ($(IFS=,; echo "${LOCALES[*]}"))"
$SCRIPT_DIR/echo-separator.sh

for index in "${!LOCALES[@]}"; do
    locale="${LOCALES[${index}]}"
    progress=$((index + 1))

    echo ""
    $SCRIPT_DIR/echo-step.sh "$(printf "[%2d/%2d] %s" "${progress}" "${TOTAL_LOCALES}" "${locale}")"

    PO_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.po"
    JSON_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.json"

    if [ ! -f "${PO_FILE}" ]; then
        $SCRIPT_DIR/echo-error.sh "PO file not found: ${PO_FILE}"
        exit 2
    fi

    if [ -f "${JSON_FILE}" ]; then
        $SCRIPT_DIR/echo-step.sh "Removing existing JSON file: ${JSON_FILE}"
        rm -f "${JSON_FILE}"
    fi

    tmp_json="$(mktemp)"
    if npx po2json "${PO_FILE}" > "${tmp_json}" 2> /dev/null; then
        mv "${tmp_json}" "${JSON_FILE}"
        if [ -f "${JSON_FILE}" ]; then
            echo "JSON file created: ${JSON_FILE}"

        else
            $SCRIPT_DIR/echo-error.sh "JSON file not created: ${JSON_FILE}"
            exit 3
        fi
    else
        rm -f "${tmp_json}"
        $SCRIPT_DIR/echo-error.sh "Could not convert: ${PO_FILE}"
        exit 4
    fi
done

echo ""
$SCRIPT_DIR/echo-separator.sh
$SCRIPT_DIR/echo-success.sh "JSON generation completed successfully"
