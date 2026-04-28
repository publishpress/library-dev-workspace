#!/usr/bin/env bash

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

processed_count=0
compiled_count=0
missing_count=0
skipped_count=0
failed_count=0

for locale in "${LOCALES[@]}"; do
    processed_count=$((processed_count + 1))
    echo ""
    echo "[${processed_count}/${TOTAL_LOCALES}] Processing locale: ${locale}"

    PO_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.po"
    MO_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.mo"

    if [ ! -f "${PO_FILE}" ]; then
        echo "MISSING PO - ${PO_FILE}"
        echo "Skipping..."
        skipped_count=$((skipped_count + 1))
        missing_count=$((missing_count + 1))
        continue
    fi

    if [ -f "${MO_FILE}" ]; then
        echo "MO file already exists, deleting it..."
        rm "${MO_FILE}"
    fi

    if wp i18n make-mo "${PO_FILE}" "${BASE_DIR}/languages" --allow-root; then
        echo "Completed successfully"
    else
        echo "FAILED TO CREATE MO - ${MO_FILE}"
        failed_count=$((failed_count + 1))
        continue
    fi

    if [ -f "${MO_FILE}" ]; then
        echo "MO file created: ${MO_FILE}"
        compiled_count=$((compiled_count + 1))
    else
        echo "FAILED TO CREATE MO - ${MO_FILE}"
        failed_count=$((failed_count + 1))
        continue
    fi
done

echo ""
echo "========================================"
echo "MO compilation finished"
echo "Processed: ${processed_count}"
echo "Compiled: ${compiled_count}"
echo "Missing PO: ${missing_count}"
echo "Skipped: ${skipped_count}"
echo "Failed: ${failed_count}"
echo "========================================"
