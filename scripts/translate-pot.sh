#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

if ! PLUGIN_FOLDER="$("$SCRIPT_DIR/plugin-folder.sh" "$REPO_ROOT")"; then
    "$SCRIPT_DIR/echo-error.sh" "Unable to determine the plugin folder from ${REPO_ROOT}/composer.json"
    exit 4
fi

if [ -z "${PLUGIN_FOLDER}" ]; then
    "$SCRIPT_DIR/echo-error.sh" "Plugin folder cannot be empty"
    exit 4
fi

$SCRIPT_DIR/echo-title.sh "PublishPress Translation: POT Generation for Plugin"
echo "Domain: ${LANG_DOMAIN}"
$SCRIPT_DIR/echo-separator.sh

POT_FILE="${REPO_ROOT}/languages/${LANG_DOMAIN}.pot"

if [ -f "${POT_FILE}" ]; then
    $SCRIPT_DIR/echo-step.sh "Removing existing POT file: ${POT_FILE}"
    rm -f "${POT_FILE}"
fi

$SCRIPT_DIR/echo-step.sh "Generating POT file: ${POT_FILE}"

if wp i18n make-pot "${REPO_ROOT}" "${POT_FILE}" \
    --domain="${LANG_DOMAIN}" \
    --exclude="vendor,.wordpress-org,.github,.cursor,.claude,.vscode,dist/${PLUGIN_FOLDER},dist/${PLUGIN_FOLDER}-tmp,tests,lib/vendor,tmp,doc,docs,.cache,dev-workspace-cache,.node_modules,.git,.zed,languages" \
    --allow-root; then
    if [ ! -f "${POT_FILE}" ]; then
        $SCRIPT_DIR/echo-error.sh "POT file was not created: ${POT_FILE}"
        exit 2
    fi
else
    $SCRIPT_DIR/echo-error.sh "Failed to create POT file: ${POT_FILE}"
    exit 3
fi

if [ ! -f "${POT_FILE}" ]; then
    $SCRIPT_DIR/echo-error.sh "POT file was not created: ${POT_FILE}"
    exit 2
fi

echo "POT file created: ${POT_FILE}"

echo ""
$SCRIPT_DIR/echo-separator.sh
$SCRIPT_DIR/echo-success.sh "POT generation completed successfully"
