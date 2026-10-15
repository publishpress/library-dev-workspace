#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/fake-plugin" && pwd)"
cd "$ROOT"
if [[ ! -f .env ]]; then
  cp .env.example .env
fi
RELEASE_RUNNER_ALLOW_DIRTY=1 composer deploy -- status --json \
  | node --input-type=module -e "const d=JSON.parse(await new Response(process.stdin).text()); if(!d.ok) { console.error(d); process.exit(1); } console.log('release-runner ok:', d.release?.edition ?? 'no release');"
