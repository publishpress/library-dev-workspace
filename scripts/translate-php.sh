#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

PLUGIN_SLUG="$("$DEV_SCRIPTS_DIR/plugin-slug.sh")"

read -r -a LOCALES <<< "${LANG_LOCALES:-}"
TOTAL_LOCALES="${#LOCALES[@]}"

if [ "${TOTAL_LOCALES}" -eq 0 ]; then
    $SCRIPT_DIR/echo-success.sh "No locales configured in LANG_LOCALES. Nothing to generate."
    exit 0
fi

$SCRIPT_DIR/echo-title.sh "PublishPress Translation: PHP Generation for Plugin"
echo "Plugin   : ${PLUGIN_SLUG}"
echo "Locales  : ${TOTAL_LOCALES} ($(IFS=,; echo "${LOCALES[*]}"))"
$SCRIPT_DIR/echo-separator.sh

for index in "${!LOCALES[@]}"; do
    locale="${LOCALES[${index}]}"
    progress=$((index + 1))
    echo ""
    $SCRIPT_DIR/echo-step.sh "$(printf "[%2d/%2d] %s" "${progress}" "${TOTAL_LOCALES}" "${locale}")"

    PO_FILE="${REPO_ROOT}/languages/${PLUGIN_SLUG}-${locale}.po"
    PHP_FILE="${REPO_ROOT}/languages/${PLUGIN_SLUG}-${locale}.l10n.php"

    if [ ! -f "${PO_FILE}" ]; then
        $SCRIPT_DIR/echo-error.sh "Missing PO file: ${PO_FILE}"
        exit 2
    fi

    if [ -f "${PHP_FILE}" ]; then
        $SCRIPT_DIR/echo-step.sh "Removing existing PHP file: ${PHP_FILE}"
        rm -f "${PHP_FILE}"
    fi

    if ! wp i18n make-php "${PO_FILE}" "${REPO_ROOT}/languages" --allow-root; then
        $SCRIPT_DIR/echo-error.sh "Failed to generate PHP file from ${PO_FILE}"
        exit 3
    fi

    if [ ! -f "${PHP_FILE}" ]; then
        $SCRIPT_DIR/echo-error.sh "PHP file was not created: ${PHP_FILE}"
        exit 4
    fi

    echo "PHP file created: ${PHP_FILE}"
done

echo ""
$SCRIPT_DIR/echo-separator.sh
$SCRIPT_DIR/echo-success.sh "PHP generation finished successfully"
