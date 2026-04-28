#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-init.sh"

if [[ "${GENERATE_TRANSLATION_JSON:-}" != "1" && "${GENERATE_TRANSLATION_JSON:-}" != "true" ]]; then
    echo "Skipping JSON translation generation (set GENERATE_TRANSLATION_JSON=1 in .env to enable)"
    exit 0
fi

BASE_DIR="/project"
PLUGIN_SLUG="$(plugin-slug.sh)"

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
    JSON_FILE="${BASE_DIR}/languages/${PLUGIN_SLUG}-${locale}.json"

    if [ ! -f "${PO_FILE}" ]; then
        echo "MISSING PO - ${PO_FILE}"
        echo "Skipping..."
        skipped_count=$((skipped_count + 1))
        missing_count=$((missing_count + 1))
        continue
    fi

    if [ -f "${JSON_FILE}" ]; then
        echo "JSON file already exists, deleting it..."
        rm "${JSON_FILE}"
    fi

    if npx po2json "${PO_FILE}" > "${JSON_FILE}"; then
        echo "Completed successfully"
    else
        echo "FAILED TO GENERATE JSON - ${JSON_FILE}"
        failed_count=$((failed_count + 1))
        continue
    fi

    if [ -f "${JSON_FILE}" ]; then
        echo "JSON file created: ${JSON_FILE}"
        generated_count=$((generated_count + 1))
    else
        echo "FAILED TO CREATE JSON - ${JSON_FILE}"
        failed_count=$((failed_count + 1))
    fi
done

echo ""
echo "========================================"
echo "JSON generation finished"
echo "Processed: ${processed_count}"
echo "Generated: ${generated_count}"
echo "Missing PO: ${missing_count}"
echo "Skipped: ${skipped_count}"
echo "Failed: ${failed_count}"
echo "========================================"
