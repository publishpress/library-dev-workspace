#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Script to display the "
    echo "Usage: dependency-versions.sh"
    echo ""
    echo "Example:"
    echo "dependency-versions.sh"
    echo ""
}

arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

separator1="$($SCRIPT_DIR/echo-separator.sh 1)"

$SCRIPT_DIR/echo-title.sh "Dependency Versions"

marker="●"
not_installed_marker="○"
indent="    "

echo "Dependency Versions:"
echo ""
echo "${indent}$marker PHP Version: " $(php -v)
echo "${indent}$marker Composer Version: " $(composer --version)
echo "${indent}$marker Node Version: " $(node -v)
echo "${indent}$marker NPM Version: " $(npm -v)
echo "${indent}$marker Yarn Version: " $(yarn -v)
echo "${indent}$marker WP-CLI Version: " $(wp --version --allow-root)

if [ -f "vendor/bin/codecept" ]; then
    echo "${indent}$marker Codeception Version: " $(vendor/bin/codecept --version)
else
    echo "${indent}$not_installed_marker Codeception Version: " "not installed"
fi

if [ -f "vendor/bin/phpcs" ]; then
    echo "${indent}$marker PHP CodeSniffer Version: " $(vendor/bin/phpcs --version)
else
    echo "${indent}$not_installed_marker PHP CodeSniffer Version: " "not installed"
fi

if [ -f "vendor/bin/phpmd" ]; then
    echo "${indent}$marker PHP Mess Detector Version: " $(vendor/bin/phpmd --version)
else
    echo "${indent}$not_installed_marker PHP Mess Detector Version: " "not installed"
fi

if [ -f "vendor/bin/phplint" ]; then
    echo "${indent}$marker PHP Lint Version: " $(vendor/bin/phplint --version)
else
    echo "${indent}$not_installed_marker PHP Lint Version: " "not installed"
fi

if [ -f "vendor/bin/phpstan" ]; then
    echo "${indent}$marker PHPStan Version: " $(vendor/bin/phpstan --version)
else
    echo "${indent}$not_installed_marker PHPStan Version: " "not installed"
fi
