#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env-bootstrap.sh
source "$SCRIPT_DIR/env-bootstrap.sh"

pass1_status=0
pass2_status=0

# Pass 1: VIP, PSR12, and project-specific standards.
echo "▶ PHPCS pass 1/2: project standards"
phpcs -p --standard=.phpcs.xml "$@" || pass1_status=$?

# Pass 2: WordPress.org org-review (Plugin Check plugin_review_phpcs).
echo "▶ PHPCS pass 2/2: WordPress.org plugin review"
if [[ -f .phpcs-plugin-review.xml ]]; then
    phpcs -p --standard=.phpcs-plugin-review.xml "$@" || pass2_status=$?
elif [[ -f vendor/publishpress/publishpress-phpcs-standards/standards/plugin-check-rulesets/plugin-review.xml ]]; then
    pass2_args=("$@")
    if [[ ${#pass2_args[@]} -eq 0 ]]; then
        pass2_args=(
            "--extensions=php"
            "--ignore=${REPO_ROOT}/dev-workspace-cache/*,${REPO_ROOT}/dist/*"
            "."
        )
    fi
    phpcs -p --standard=vendor/publishpress/publishpress-phpcs-standards/standards/plugin-check-rulesets/plugin-review.xml "${pass2_args[@]}" || pass2_status=$?
else
    echo "Plugin Check ruleset not found. Run composer config:plugin-check." >&2
    exit 1
fi

if [[ $pass1_status -ne 0 || $pass2_status -ne 0 ]]; then
    exit 1
fi
