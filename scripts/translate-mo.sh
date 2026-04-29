#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/project"
PLUGIN_SLUG="$(plugin-slug.sh)"
read -r -a LOCALES <<< "${LANG_LOCALES:-}"
TOTAL_LOCALES="${#LOCALES[@]}"

if [ "${TOTAL_LOCALES}" -eq 0 ]; then
    echo "No locales configured in LANG_LOCALES. Nothing to compile."
    exit 0
fi

echo "========================================"
echo "Starting MO compilation"
echo "Plugin: ${PLUGIN_SLUG}"
echo "Locales to process: ${TOTAL_LOCALES}"
echo "========================================"

for index in "${!LOCALES[@]}"; do
    locale="${LOCALES[${index}]}"
    progress=$((index + 1))
    echo ""
    echo "[${progress}/${TOTAL_LOCALES}] Processing locale: ${locale}"

    PO_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.po"
    MO_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.mo"

    if [ ! -f "${PO_FILE}" ]; then
        echo "ERROR: Missing PO file: ${PO_FILE}"
        exit 1
    fi

    if ! wp i18n make-mo "${PO_FILE}" "${BASE_DIR}/languages" --allow-root; then
        echo "ERROR: Failed to create MO file from ${PO_FILE}"
        exit 2
    fi

    if [ ! -f "${MO_FILE}" ]; then
        echo "ERROR: MO file was not created: ${MO_FILE}"
        exit 3
    fi

    echo "MO file created: ${MO_FILE}"
done

echo ""
echo "========================================"
echo "MO compilation finished successfully"
echo "========================================"
