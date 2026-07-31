#!/usr/bin/env bash

set -euo pipefail

vendor/bin/phpcs --config-set installed_paths "../../phpcsstandards/phpcsutils,../../phpcsstandards/phpcsextra,../../automattic/vipwpcs,../../phpcompatibility/php-compatibility,../../sirbrillig/phpcs-variable-analysis,../../publishpress/publishpress-phpcs-standards/standards,../../wp-coding-standards/wpcs" > /dev/null 2>&1

echo "PHPCS installed paths configured"
