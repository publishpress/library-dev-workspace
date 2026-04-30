#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

PLUGIN_SLUG="$("$SCRIPT_DIR/plugin-slug.sh")"
read -r -a LOCALES <<< "${LANG_LOCALES:-}"
TOTAL_LOCALES="${#LOCALES[@]}"

if [ "${TOTAL_LOCALES}" -eq 0 ]; then
    echo "No locales configured in LANG_LOCALES. Nothing to compile."
    exit 0
fi

$SCRIPT_DIR/echo-title.sh "PublishPress Translation: MO Compilation for Plugin"
echo "Plugin   : ${PLUGIN_SLUG}"
echo "Locales  : ${TOTAL_LOCALES} ($(IFS=,; echo "${LOCALES[*]}"))"
$SCRIPT_DIR/echo-separator.sh

for index in "${!LOCALES[@]}"; do
    locale="${LOCALES[${index}]}"
    progress=$((index + 1))
    echo ""
    $SCRIPT_DIR/echo-step.sh "$(printf "[%2d/%2d] %s" "${progress}" "${TOTAL_LOCALES}" "${locale}")"

    PO_FILE="${REPO_ROOT}/languages/${PLUGIN_SLUG}-${locale}.po"
    MO_FILE="${REPO_ROOT}/languages/${PLUGIN_SLUG}-${locale}.mo"

    if [ ! -f "${PO_FILE}" ]; then
        $SCRIPT_DIR/echo-error.sh "Missing PO file: ${PO_FILE}"
        exit 2
    fi

    if [ -f "${MO_FILE}" ]; then
        $SCRIPT_DIR/echo-step.sh "Removing existing MO file: ${MO_FILE}"
        rm -f "${MO_FILE}"
    fi

    if ! wp i18n make-mo "${PO_FILE}" "${REPO_ROOT}/languages" --allow-root; then
        $SCRIPT_DIR/echo-error.sh "Failed to create MO file from ${PO_FILE}"
        exit 3
    fi

    if [ ! -f "${MO_FILE}" ]; then
        $SCRIPT_DIR/echo-error.sh "MO file was not created: ${MO_FILE}"
        exit 4
    fi

    echo "MO file created: ${MO_FILE}"
done

echo ""
$SCRIPT_DIR/echo-separator.sh
$SCRIPT_DIR/echo-success.sh "MO compilation finished successfully"
