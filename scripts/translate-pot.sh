#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/project"

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-bootstrap.sh"

echo "========================================"
echo "Starting POT generation"
echo "Domain: ${LANG_DOMAIN}"
echo "========================================"

POT_FILE="${BASE_DIR}/languages/${LANG_DOMAIN}.pot"

if wp i18n make-pot . "${POT_FILE}" \
    --domain=${LANG_DOMAIN} \
    --exclude=vendor,.wordpress-org,.github,.cursor,.claude,.vscode,dist,tests,lib/vendor,tmp,doc,docs,.cache,dev-workspace-cache,.node_modules,.git,.zed,languages \
    --allow-root; then
    if [ ! -f "${POT_FILE}" ]; then
        echo "ERROR: POT file was not created: ${POT_FILE}"
        exit 2
    fi
else
    echo "ERROR: Failed to create POT file: ${POT_FILE}"
    exit 1
fi

echo "POT file created: ${POT_FILE}"
echo "Completed successfully"
echo "========================================"
