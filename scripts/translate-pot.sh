#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/project"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-bootstrap.sh"

$SCRIPT_DIR/echo-title.sh "PublishPress Translation: POT Generation for Plugin"
echo ""
echo "Domain: ${LANG_DOMAIN}"
$SCRIPT_DIR/echo-separator.sh

POT_FILE="${BASE_DIR}/languages/${LANG_DOMAIN}.pot"

if [ -f "${POT_FILE}" ]; then
    $SCRIPT_DIR/echo-step.sh "Removing existing POT file: ${POT_FILE}"
    rm -f "${POT_FILE}"
fi

$SCRIPT_DIR/echo-step.sh "Generating POT file: ${POT_FILE}"

if wp i18n make-pot . "${POT_FILE}" \
    --domain=${LANG_DOMAIN} \
    --exclude=vendor,.wordpress-org,.github,.cursor,.claude,.vscode,dist,tests,lib/vendor,tmp,doc,docs,.cache,dev-workspace-cache,.node_modules,.git,.zed,languages \
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
