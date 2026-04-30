#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Script to parse JSON files and extract property values using jq"
    echo "Usage: parse-json.sh <json_file_path> <property_path>"
    echo ""
    echo "Arguments:"
    echo "  json_file_path    Path to the JSON file to parse"
    echo "  property_path     Property path using dot notation (e.g., 'extra.plugin-name' or 'name')"
    echo ""
    echo "Options:"
    echo "  -h, --help        Display this help message"
}

# Check for help flag
arg1="${1:-}"
if [ "$arg1" = "-h" ] || [ "$arg1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if required arguments are provided
if [ -z "$arg1" ] || [ -z "$arg2" ]; then
    show_help
    exit 1
fi

json_file="$arg1"
property_path="$arg2"

# Check if the JSON file exists
if [ ! -f "$json_file" ]; then
    "$SCRIPT_DIR/echo-error.sh" "Error: JSON file not found: $json_file"
    exit 2
fi

# Convert dot notation to jq path format
# e.g., "extra.plugin-name" -> '.extra["plugin-name"]'
# We need to handle properties that may contain hyphens by using bracket notation
IFS='.' read -ra parts <<< "$property_path"
jq_path=""

for part in "${parts[@]}"; do
    # If part contains hyphen or special characters, use bracket notation
    if [[ "$part" =~ [^a-zA-Z0-9_] ]]; then
        jq_path="${jq_path}[\"${part}\"]"
    else
        # For simple identifiers, use dot notation
        if [ -z "$jq_path" ]; then
            jq_path=".${part}"
        else
            jq_path="${jq_path}.${part}"
        fi
    fi
done

# Extract the value using jq
result=$(jq -r "$jq_path // empty" "$json_file" 2>/dev/null)

# Check if jq command was successful and returned a value
if [ $? -ne 0 ]; then
    "$SCRIPT_DIR/echo-error.sh" "Error: Failed to parse JSON file"
    exit 3
fi

if [ -z "$result" ]; then
    "$SCRIPT_DIR/echo-error.sh" "Error: Property '$property_path' not found in the JSON file."
    exit 4
fi

# Output the result
echo "$result"
