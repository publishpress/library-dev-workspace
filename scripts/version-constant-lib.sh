#!/usr/bin/env bash
# Shared version-constant helpers for check-release.sh and check-wporg.sh.
# Keep candidate basenames in sync with scripts/plugin-bump-version.php.

VERSION_CONSTANT_BASENAMES=(defines.php constants.php include.php)

# BusyBox sed (dev-workspace terminal) cannot match quote pairs via backreferences;
# try all strict define('NAME', 'value') / define("NAME", "value") combinations.
_extract_constant_version_with_sed() {
    local input_file="$1"
    local constant="$2"
    local q1 q2 pattern result

    for q1 in "'" '"'; do
        for q2 in "'" '"'; do
            pattern="s/.*define\\(${q1}${constant}${q1},[[:space:]]*${q2}([^${q2}]+)${q2}\\).*/\\1/p"
            result="$(sed -nE "$pattern" "$input_file" | head -1 | tr -d '\r')"
            if [[ -n "$result" ]]; then
                echo "$result"
                return 0
            fi
        done
    done

    echo ""
}

extract_constant_version_from_stream() {
    local constant="$1"
    local tmp_file=""

    if [[ -z "$constant" ]]; then
        echo ""
        return
    fi

    tmp_file="$(mktemp)"
    cat > "$tmp_file"
    _extract_constant_version_with_sed "$tmp_file" "$constant"
    rm -f "$tmp_file"
}

extract_constant_version() {
    local file="$1"
    local constant="$2"
    if [[ ! -f "$file" || -z "$constant" ]]; then
        echo ""
        return
    fi
    _extract_constant_version_with_sed "$file" "$constant"
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
