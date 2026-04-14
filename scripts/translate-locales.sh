#!/usr/bin/env bash
# Run publishpress-translate with LANG_LOCALES from .env as a comma-separated list.
# Intended to be called via run.sh after env-init.sh has loaded and exported LANG_LOCALES.
set -euo pipefail

DEFAULT_LANG_LOCALES="ja es_ES de_DE fr_FR pt_BR it_IT nl_NL ru_RU pl_PL tr_TR vi fa_IR id_ID cs_CZ pt_PT zh_CN sv_SE hu_HU da_DK ar he_IL ko_KR ro_RO el th fi"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CSV="$("$SCRIPT_DIR/spaces-to-csv.sh" "${LANG_LOCALES:-$DEFAULT_LANG_LOCALES}")"

exec "vendor/bin/publishpress-translate" --languages="$CSV"
