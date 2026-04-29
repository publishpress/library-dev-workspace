#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-init.sh"

if [[ "${GENERATE_TRANSLATION_JSON:-}" != "1" && "${GENERATE_TRANSLATION_JSON:-}" != "true" ]]; then
    echo "Skipping JSON translation generation (set GENERATE_TRANSLATION_JSON=1 in .env to enable)"
    exit 0
fi

BASE_DIR="/project"
PLUGIN_SLUG="$("$DEV_SCRIPTS_DIR/plugin-slug.sh")"

read -r -a LOCALES <<< "${LANG_LOCALES:-}"
TOTAL_LOCALES="${#LOCALES[@]}"

if [ "${TOTAL_LOCALES}" -eq 0 ]; then
    echo "No locales configured in LANG_LOCALES. Nothing to generate."
    exit 0
fi

echo "========================================"
echo "Starting JSON generation"
echo "Plugin: ${PLUGIN_SLUG}"
echo "Locales to process: ${TOTAL_LOCALES}"
echo "========================================"

for index in "${!LOCALES[@]}"; do
    locale="${LOCALES[${index}]}"
    progress=$((index + 1))
    echo ""
    echo "[${progress}/${TOTAL_LOCALES}] Processing locale: ${locale}"

    PO_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.po"
    JSON_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.json"

    if [ ! -f "${PO_FILE}" ]; then
        echo "ERROR: Missing PO file: ${PO_FILE}"
        exit 1
    fi

    tmp_json="$(mktemp)"

    if npx po2json "${PO_FILE}" > "${tmp_json}"; then
        mv "${tmp_json}" "${JSON_FILE}"
        echo "JSON file created: ${JSON_FILE}"
    else
        rm -f "${tmp_json}"
        echo "ERROR: Failed to generate JSON from ${PO_FILE}"
        exit 2
    fi

    if [ ! -f "${JSON_FILE}" ]; then
        echo "ERROR: JSON file was not created: ${JSON_FILE}"
        exit 3
    fi
done

echo ""
echo "========================================"
echo "JSON generation finished successfully"
echo "========================================"
