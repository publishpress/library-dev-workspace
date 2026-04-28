#!/usr/bin/env bash

BASE_DIR="/project"

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-init.sh"

echo "========================================"
echo "Starting POT generation"
echo "Domain: ${LANG_DOMAIN}"
echo "========================================"

POT_FILE="${BASE_DIR}/languages/${LANG_DOMAIN}.pot"

if wp i18n make-pot . "${POT_FILE}" \
    --domain=${LANG_DOMAIN} \
    --exclude=vendor,.wordpress-org,.github,.cursor,.claude,.vscode,dist,tests,lib/vendor,tmp,doc,docs,.cache,dev-workspace-cache,.node_modules,.git,.zed,languages \
    --allow-root; then
    echo "POT file created: ${POT_FILE}"
    echo "Completed successfully"
else
    echo "FAILED TO CREATE POT - ${POT_FILE}"
fi
echo "========================================"
