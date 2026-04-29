#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-init.sh"

BASE_DIR="/project"
PLUGIN_SLUG="$("$DEV_SCRIPTS_DIR/plugin-slug.sh")"

read -r -a LOCALES <<< "${LANG_LOCALES:-}"
TOTAL_LOCALES="${#LOCALES[@]}"

if [ "${TOTAL_LOCALES}" -eq 0 ]; then
    echo "No locales configured in LANG_LOCALES. Nothing to generate."
    exit 0
fi

echo "========================================"
echo "Starting PHP generation"
echo "Plugin: ${PLUGIN_SLUG}"
echo "Locales to process: ${TOTAL_LOCALES}"
echo "========================================"

for index in "${!LOCALES[@]}"; do
    locale="${LOCALES[${index}]}"
    progress=$((index + 1))
    echo ""
    echo "[${progress}/${TOTAL_LOCALES}] Processing locale: ${locale}"

    PO_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.po"
    PHP_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.l10n.php"

    if [ ! -f "${PO_FILE}" ]; then
        echo "ERROR: Missing PO file: ${PO_FILE}"
        exit 1
    fi

    if ! wp i18n make-php "${PO_FILE}" "${BASE_DIR}/languages" --allow-root; then
        echo "ERROR: Failed to generate PHP file from ${PO_FILE}"
        exit 2
    fi

    if [ ! -f "${PHP_FILE}" ]; then
        echo "ERROR: PHP file was not created: ${PHP_FILE}"
        exit 3
    fi

    echo "PHP file created: ${PHP_FILE}"
done

echo ""
echo "========================================"
echo "PHP generation finished successfully"
echo "========================================"
