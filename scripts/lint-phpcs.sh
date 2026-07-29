#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env-bootstrap.sh
source "$SCRIPT_DIR/env-bootstrap.sh"

# Pass 1: VIP, PSR12, and project-specific standards.
phpcs --standard=.phpcs.xml "$@"

# Pass 2: WordPress.org org-review (Plugin Check plugin_review_phpcs).
if [[ -f .phpcs-plugin-review.xml ]]; then
    phpcs --standard=.phpcs-plugin-review.xml "$@"
elif [[ -f vendor/wordpress/plugin-check/phpcs-rulesets/plugin-review.xml ]]; then
    phpcs --standard=vendor/wordpress/plugin-check/phpcs-rulesets/plugin-review.xml "$@"
else
    echo "Plugin Check ruleset not found. Run composer install." >&2
    exit 1
fi
