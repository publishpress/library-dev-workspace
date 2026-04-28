#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/project"
PLUGIN_SLUG="$(plugin-slug.sh)"

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

processed_count=0
generated_count=0
missing_count=0
skipped_count=0
failed_count=0

for locale in "${LOCALES[@]}"; do
    processed_count=$((processed_count + 1))
    echo ""
    echo "[${processed_count}/${TOTAL_LOCALES}] Processing locale: ${locale}"

    PO_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.po"
    PHP_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.php"

    if [ ! -f "${PO_FILE}" ]; then
        echo "MISSING PO - ${PO_FILE}"
        echo "Skipping..."
        skipped_count=$((skipped_count + 1))
        missing_count=$((missing_count + 1))
        continue
    fi

    if [ -f "${PHP_FILE}" ]; then
        echo "JSON file already exists, deleting it..."
        rm "${PHP_FILE}"
    fi

    if wp i18n make-php ./languages --allow-root; then
        echo "Completed successfully"
    else
        echo "FAILED TO GENERATE PHP - ${PHP_FILE}"
        failed_count=$((failed_count + 1))
        continue
    fi

    if [ -f "${PHP_FILE}" ]; then
        echo "PHP file created: ${PHP_FILE}"
        generated_count=$((generated_count + 1))
    else
        echo "FAILED TO CREATE PHP - ${PHP_FILE}"
        failed_count=$((failed_count + 1))
    fi
done

echo ""
echo "========================================"
echo "PHP generation finished"
echo "Processed: ${processed_count}"
echo "Generated: ${generated_count}"
echo "Missing PO: ${missing_count}"
echo "Skipped: ${skipped_count}"
echo "Failed: ${failed_count}"
echo "========================================"
