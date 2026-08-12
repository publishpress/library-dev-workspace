#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env-bootstrap.sh
source "$SCRIPT_DIR/env-bootstrap.sh"

pass1_status=0
pass2_status=0

# Pass 1: VIP, PSR12, and project-specific standards.
phpcs --standard=.phpcs.xml "$@" || pass1_status=$?

# Pass 2: WordPress.org org-review (Plugin Check plugin_review_phpcs).
# Only run when the project provides a project-level ruleset. Pro/non-wp.org
# plugins should not be forced through this pass just because the vendor
# ruleset happens to be installed.
if [[ -f .phpcs-plugin-review.xml ]]; then
    phpcs --standard=.phpcs-plugin-review.xml "$@" || pass2_status=$?
fi

if [[ $pass1_status -ne 0 || $pass2_status -ne 0 ]]; then
    exit 1
fi
