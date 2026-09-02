#!/usr/bin/env bash
# Shared version-constant helpers for check-release.sh and check-wporg.sh.
# Keep candidate basenames in sync with scripts/plugin-bump-version.php.

VERSION_CONSTANT_BASENAMES=(defines.php constants.php include.php)

_version_constant_sed_pattern() {
    local constant="$1"
    echo "s/.*define\\((['\"])${constant}\\1,[[:space:]]*(['\"])([^'\"]+)\\2\\).*/\\3/p"
}

extract_constant_version_from_stream() {
    local constant="$1"
    if [[ -z "$constant" ]]; then
        echo ""
        return
    fi
    sed -nE "$(_version_constant_sed_pattern "$constant")" | head -1 | tr -d '\r'
}

extract_constant_version() {
    local file="$1"
    local constant="$2"
    if [[ ! -f "$file" || -z "$constant" ]]; then
        echo ""
        return
    fi
    sed -nE "$(_version_constant_sed_pattern "$constant")" "$file" | head -1 | tr -d '\r'
}

version_constant_filesystem_candidates() {
    local base_path="$1"
    local plugin_slug="$2"

    echo "${base_path}/${plugin_slug}.php"
    local basename
    for basename in "${VERSION_CONSTANT_BASENAMES[@]}"; do
        echo "${base_path}/${basename}"
    done
}

version_constant_zip_members() {
    local plugin_slug="$1"

    echo "${plugin_slug}/${plugin_slug}.php"
    local basename
    for basename in "${VERSION_CONSTANT_BASENAMES[@]}"; do
        echo "${plugin_slug}/${basename}"
    done
}

# Sets VERSION_CONSTANT_CHECK_STATUS and VERSION_CONSTANT_CHECK_DETAIL on exit.
# Status: ok | missing | duplicate | mismatch
validate_version_constant_in_paths() {
    local constant="$1"
    local expected_version="$2"
    shift 2

    local -a found_labels=()
    local -a found_values=()
    local path label value

    VERSION_CONSTANT_CHECK_STATUS=""
    VERSION_CONSTANT_CHECK_DETAIL=""

    for path in "$@"; do
        if [[ -f "$path" ]]; then
            value="$(extract_constant_version "$path" "$constant")"
            if [[ -n "$value" ]]; then
                found_labels+=("$(basename "$path")")
                found_values+=("$value")
            fi
        fi
    done

    if [[ "${#found_labels[@]}" -eq 0 ]]; then
        VERSION_CONSTANT_CHECK_STATUS="missing"
        VERSION_CONSTANT_CHECK_DETAIL="constant '${constant}' not found in main plugin file, defines.php, constants.php, or include.php"
        return 1
    fi

    if [[ "${#found_labels[@]}" -gt 1 ]]; then
        VERSION_CONSTANT_CHECK_STATUS="duplicate"
        VERSION_CONSTANT_CHECK_DETAIL="constant '${constant}' defined in multiple files: ${found_labels[*]}"
        return 1
    fi

    if [[ "${found_values[0]}" != "$expected_version" ]]; then
        VERSION_CONSTANT_CHECK_STATUS="mismatch"
        VERSION_CONSTANT_CHECK_DETAIL="expected ${expected_version}, got '${found_values[0]}' (${found_labels[0]})"
        return 1
    fi

    VERSION_CONSTANT_CHECK_STATUS="ok"
    VERSION_CONSTANT_CHECK_DETAIL="${constant}=${found_values[0]} (${found_labels[0]})"
    return 0
}

# Same rules as validate_version_constant_in_paths, but reads members from a ZIP.
validate_version_constant_in_zip() {
    local zip_file="$1"
    local constant="$2"
    local expected_version="$3"
    shift 3

    local -a found_labels=()
    local -a found_values=()
    local member label value

    VERSION_CONSTANT_CHECK_STATUS=""
    VERSION_CONSTANT_CHECK_DETAIL=""

    for member in "$@"; do
        value="$(unzip -p "$zip_file" "$member" 2>/dev/null | extract_constant_version_from_stream "$constant")"
        if [[ -n "$value" ]]; then
            found_labels+=("${member##*/}")
            found_values+=("$value")
        fi
    done

    if [[ "${#found_labels[@]}" -eq 0 ]]; then
        VERSION_CONSTANT_CHECK_STATUS="missing"
        VERSION_CONSTANT_CHECK_DETAIL="constant '${constant}' not found in main plugin file, defines.php, constants.php, or include.php"
        return 1
    fi

    if [[ "${#found_labels[@]}" -gt 1 ]]; then
        VERSION_CONSTANT_CHECK_STATUS="duplicate"
        VERSION_CONSTANT_CHECK_DETAIL="constant '${constant}' defined in multiple files: ${found_labels[*]}"
        return 1
    fi

    if [[ "${found_values[0]}" != "$expected_version" ]]; then
        VERSION_CONSTANT_CHECK_STATUS="mismatch"
        VERSION_CONSTANT_CHECK_DETAIL="expected ${expected_version}, got '${found_values[0]}' (${found_labels[0]})"
        return 1
    fi

    VERSION_CONSTANT_CHECK_STATUS="ok"
    VERSION_CONSTANT_CHECK_DETAIL="${constant}=${found_values[0]} (${found_labels[0]})"
    return 0
}
