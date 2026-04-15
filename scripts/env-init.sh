#!/usr/bin/env bash

DEV_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_WORKSPACE_DIR="$(cd "$DEV_SCRIPTS_DIR/.." && pwd)"
REPO_ROOT="$(cd "$DEV_WORKSPACE_DIR/../../.." && pwd)"

# Subprocesses (e.g. pack.sh spawned from run.sh) must inherit these paths.
export DEV_SCRIPTS_DIR DEV_WORKSPACE_DIR REPO_ROOT

if [[ ! -f "$REPO_ROOT/.env" ]]; then
    echo "Error: .env file not found. Run 'cp .env.example .env' to create it."
    exit 1
fi

set -a
source "$REPO_ROOT/.env"
set +a

if [[ "$CACHE_PATH" != /* ]]; then
    CACHE_PATH="$REPO_ROOT/$CACHE_PATH"
fi

export DEFAULT_LANG_LOCALES="${DEFAULT_LANG_LOCALES:-ja es_ES de_DE fr_FR pt_BR it_IT nl_NL ru_RU pl_PL tr_TR vi fa_IR id_ID cs_CZ pt_PT zh_CN sv_SE hu_HU da_DK ar he_IL ko_KR ro_RO el th fi}"
export LANG_LOCALES="${LANG_LOCALES:-$DEFAULT_LANG_LOCALES}"
