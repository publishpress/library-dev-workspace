#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$REPO_ROOT/scripts/require-weblate-access.sh"
passes=0
failures=0

pass() {
    passes=$((passes + 1))
    echo "PASS  $1"
}

fail() {
    failures=$((failures + 1))
    echo "FAIL  $1 — $2"
}

run_guard() {
    local status=0
    RUN_OUTPUT="$(env -u CF_ACCESS_CLIENT_ID -u CF_ACCESS_CLIENT_SECRET -u WEBLATE_API_URL "$@" bash "$GUARD" "${CMD[@]}")" || status=$?
    RUN_STATUS=$status
}

CMD=(vendor/bin/publishpress-translate --download)
run_guard
if [[ "$RUN_STATUS" -ne 0 && "$RUN_OUTPUT" == *"CF_ACCESS_CLIENT_ID"* ]]; then
    pass "missing token blocks download"
else
    fail "missing token blocks download" "status=$RUN_STATUS output=$RUN_OUTPUT"
fi

CMD=(vendor/publishpress/dev-workspace/scripts/translate-locales.sh)
run_guard
if [[ "$RUN_STATUS" -ne 0 ]]; then
    pass "missing token blocks translate-locales"
else
    fail "missing token blocks translate-locales" "status=$RUN_STATUS"
fi

CMD=(vendor/bin/publishpress-translate --audit)
run_guard
if [[ "$RUN_STATUS" -eq 0 ]]; then
    pass "audit does not need the token"
else
    fail "audit does not need the token" "status=$RUN_STATUS output=$RUN_OUTPUT"
fi

CMD=(vendor/bin/publishpress-translate --dry-run)
run_guard
if [[ "$RUN_STATUS" -eq 0 ]]; then
    pass "dry-run does not need the token"
else
    fail "dry-run does not need the token" "status=$RUN_STATUS output=$RUN_OUTPUT"
fi

CMD=(vendor/bin/publishpress-translate --download)
run_guard CF_ACCESS_CLIENT_ID='id.access' CF_ACCESS_CLIENT_SECRET='secret'
if [[ "$RUN_STATUS" -eq 0 ]]; then
    pass "both tokens allow download"
else
    fail "both tokens allow download" "status=$RUN_STATUS output=$RUN_OUTPUT"
fi

CMD=(vendor/bin/publishpress-translate --download)
run_guard CF_ACCESS_CLIENT_ID='   ' CF_ACCESS_CLIENT_SECRET='secret'
if [[ "$RUN_STATUS" -ne 0 ]]; then
    pass "blank token blocks download"
else
    fail "blank token blocks download" "status=$RUN_STATUS"
fi

CMD=(vendor/bin/publishpress-translate --download)
run_guard WEBLATE_API_URL='https://weblate.example.test/api/'
if [[ "$RUN_STATUS" -eq 0 ]]; then
    pass "other Weblate host skips the check"
else
    fail "other Weblate host skips the check" "status=$RUN_STATUS output=$RUN_OUTPUT"
fi

echo "$passes passed, $failures failed"
if [[ "$failures" -ne 0 ]]; then
    exit 1
fi
