#!/usr/bin/env bash

# Script to pack a plugin into a directory and create a zip file from it.

# Enable pipefail so pipelines return the exit code of the first failing command
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

start_time=$(date +%s)

include_debug=0
if [[ "${PACK_INCLUDE_DEBUG:-}" == "1" ]]; then
    include_debug=1
fi

pack_args=()
for a in "$@"; do
    case "$a" in
    --with-debug)
        include_debug=1
        ;;
    *)
        pack_args+=("$a")
        ;;
    esac
done
set -- "${pack_args[@]}"

command=${1:-}
default_source_path="/project"
source_path="${GITHUB_WORKSPACE:-$default_source_path}"
dist_path="${source_path}/dist"

plugin_name=$("$SCRIPT_DIR/plugin-name.sh")
plugin_slug=$("$SCRIPT_DIR/plugin-slug.sh")
plugin_folder=$("$SCRIPT_DIR/plugin-folder.sh")
plugin_version=$("$SCRIPT_DIR/plugin-version.sh")
tmp_build_dir="${dist_path}/${plugin_folder}"
tmp_internal_vendor_dir="${tmp_build_dir}/lib"

# Function to display help text
show_help() {
    echo "Script to pack the plugin to the dist directory or create a zip file"
    echo "Usage: pack.sh [command] [--with-debug]"
    echo "Commands:"
    echo "  dir          Pack the plugin to the dist directory."
    echo "  zip          Pack the plugin and create a zip file."
    echo "  clean        Clean the dist directory."
    echo "  version      Get the plugin version."
    echo ""
    echo "Options:"
    echo "  --with-debug Include debug-oriented assets in the pack (e.g. *.map, /assets/jsx)."
    echo "               Omit strip-debug rsync filter layers. Same effect as PACK_INCLUDE_DEBUG=1."
    echo "  -h, --help   Show this help message."
    echo "  HIDE_HEADER  Set this environment variable to '1' to hide the header when running the script."
    echo "               HIDE_HEADER=1 pack.sh build"
}

check_composer_extra_info() {
    "$SCRIPT_DIR/echo-step.sh" "Checking composer extra info"
    local source_path=$1

    local composer_file="${source_path}/composer.json"
    if [ ! -f "$composer_file" ]; then
        "$SCRIPT_DIR/echo-error.sh" "Error: $composer_file does not exist."
        exit 2
    fi

    # Check if jq is installed for robust JSON parsing
    if ! command -v jq >/dev/null 2>&1; then
        "$SCRIPT_DIR/echo-error.sh" "Error: jq is required to validate extra fields in composer.json."
        exit 3
    fi

    # Check for required fields in the "extra" object (paths are dot notation; jq keys are the segment after "extra.")
    local missing_fields=()
    local required_fields=("extra.plugin-name" "extra.plugin-slug" "extra.plugin-folder" "extra.plugin-lang-domain" "extra.plugin-github-repo" "extra.plugin-composer-package")
    for field in "${required_fields[@]}"; do
        local value
        local extra_key="${field#extra.}"
        value=$(jq -r --arg k "$extra_key" '.extra[$k] // empty' "$composer_file")
        if [ -z "$value" ] || [ "$value" = "null" ]; then
            missing_fields+=("$field")
        fi
    done

    if [ "${#missing_fields[@]}" -ne 0 ]; then
        "$SCRIPT_DIR/echo-error.sh" "Error: The following required 'extra' fields are missing in $composer_file: ${missing_fields[*]}"
        exit 4
    fi

    "$SCRIPT_DIR/echo-success.sh" "All required 'extra' fields are present in $composer_file."
}

check_composer_extra_info "${source_path}"

# Check if user wants to see help or no command is provided
if [[ ${command} == "-h" || ${command} == "--help" || -z "${command}" ]]; then
    "$SCRIPT_DIR/echo-builder-header.sh"
    echo ""
    show_help
    exit 0
fi

if [ "${HIDE_HEADER}" != "1" ]; then
    "$SCRIPT_DIR/echo-builder-header.sh"
fi

show_elapsed_time() {
    "$SCRIPT_DIR/show-time.sh" "${start_time}"
}

# Run a command with indented output (preserves colors)
# Usage: run_indented <exit_code> <command> [args...]
run_indented() {
    echo ""
    echo "┌──"
    local exit_code=$1
    shift
    "$@" 2>&1 | while IFS= read -r line; do echo "│ $line"; done || exit $exit_code
    echo "└──"
    echo ""
}

command_dir() {
    "$SCRIPT_DIR/echo-command-header.sh" "Cleaning dist directory"
    "$SCRIPT_DIR/clean-dist.sh" "${tmp_build_dir}"

    "$SCRIPT_DIR/echo-command-header.sh" "Building plugin to dist directory"

    pre_merge_count=0
    rsync_pre_filters=()
    add_pre_merge() {
        local f="$1"
        if [[ -f "$f" ]]; then
            rsync_pre_filters+=( -f "merge ${f}" )
            pre_merge_count=$((pre_merge_count + 1))
        fi
    }

    add_pre_merge "${DEV_WORKSPACE_DIR}/.rsync-filters-pre-build.default"
    if [[ "${include_debug}" != "1" ]]; then
        add_pre_merge "${DEV_WORKSPACE_DIR}/.rsync-filters-pre-build.strip-debug"
        add_pre_merge "${source_path}/.rsync-filters-pre-build.strip-debug"
    fi
    add_pre_merge "${source_path}/.rsync-filters-pre-build"

    if [[ "${pre_merge_count}" -eq 0 ]]; then
        "$SCRIPT_DIR/echo-error.sh" "No pre-build rsync filter files found. Add vendor/publishpress/dev-workspace/.rsync-filters-pre-build.default and/or .rsync-filters-pre-build."
        exit 5
    fi

    if [[ "${include_debug}" == "1" ]]; then
        "$SCRIPT_DIR/echo-step.sh" "Packing with debug assets (strip-debug filters skipped)"
    else
        "$SCRIPT_DIR/echo-step.sh" "Packing in release style (debug assets excluded via strip-debug filters)"
    fi

    "$SCRIPT_DIR/echo-step.sh" "Copying plugin files to dist (layered pre-build rsync filters)"
    if ! mkdir -p "${tmp_build_dir}"; then
        "$SCRIPT_DIR/echo-error.sh" "Failed to create temporary build directory"
        exit 6
    fi

    if ! rsync -r "${rsync_pre_filters[@]}" "${source_path}/" "${tmp_build_dir}"; then
        "$SCRIPT_DIR/echo-error.sh" "Failed to copy plugin files to temporary build directory"
        exit 7
    fi

    if [ -d "${tmp_internal_vendor_dir}" ]; then
        "$SCRIPT_DIR/echo-step.sh" "Installing dependencies on ${tmp_internal_vendor_dir}/vendor"
        echo ""
        run_indented 8 composer install --no-dev --optimize-autoloader --classmap-authoritative --ansi --working-dir="${tmp_internal_vendor_dir}"
    fi

    post_merge_count=0
    rsync_post_filters=()
    add_post_merge() {
        local f="$1"
        if [[ -f "$f" ]]; then
            rsync_post_filters+=( -f "merge ${f}" )
            post_merge_count=$((post_merge_count + 1))
        fi
    }

    add_post_merge "${DEV_WORKSPACE_DIR}/.rsync-filters-post-build.default"
    add_post_merge "${source_path}/.rsync-filters-post-build"

    if [[ "${post_merge_count}" -eq 0 ]]; then
        "$SCRIPT_DIR/echo-error.sh" "No post-build rsync filter files found. Add vendor/publishpress/dev-workspace/.rsync-filters-post-build.default and/or .rsync-filters-post-build."
        exit 9
    fi

    "$SCRIPT_DIR/echo-step.sh" "Removing files listed in layered post-build rsync filters"
    if ! rsync -r "${rsync_post_filters[@]}" "${tmp_build_dir}/" "${tmp_build_dir}-tmp"; then
        "$SCRIPT_DIR/echo-error.sh" "Failed to remove files listed in layered post-build rsync filters"
        exit 10
    fi

    if ! rm -rf "${tmp_build_dir}"; then
        "$SCRIPT_DIR/echo-error.sh" "Failed to remove temporary build directory"
        exit 11
    fi

    "$SCRIPT_DIR/echo-command-header.sh" "Moving the temporary build directory to the final build directory"

    "$SCRIPT_DIR/echo-step.sh" "Moving to ${tmp_build_dir}"
    if ! mv "${tmp_build_dir}-tmp" "${tmp_build_dir}"; then
        "$SCRIPT_DIR/echo-error.sh" "Failed to move temporary build directory to final build directory"
        exit 12
    fi

    "$SCRIPT_DIR/echo-command-header.sh" "Verifying the build directory ${tmp_build_dir}"
    if [ ! -d "${tmp_build_dir}" ]; then
        "$SCRIPT_DIR/echo-error.sh" "Build directory ${tmp_build_dir} does not exist"
        exit 13
    else
        "$SCRIPT_DIR/echo-step.sh" "Asserting that build directory ${tmp_build_dir} exists"
        "$SCRIPT_DIR/echo-step.sh" "Listing the build directory ${tmp_build_dir}"
        echo ""
        run_indented 14 ls -lha "${tmp_build_dir}"
    fi
}

command_zip() {
    "$SCRIPT_DIR/echo-command-header.sh" "Packaging plugin directory into zip archive"

    zip_filename=$("$SCRIPT_DIR/plugin-zipfile.sh" "$source_path")
    zip_path="${dist_path}/${zip_filename}"

    "$SCRIPT_DIR/echo-step.sh" "Removing old zip file on ${zip_path}, if exists"
    if ! rm -f "${zip_path}"; then
        "$SCRIPT_DIR/echo-error.sh" "Failed to remove old zip file"
        exit 15
    fi

    if ! pushd "${dist_path}" >/dev/null 2>&1; then
        "$SCRIPT_DIR/echo-error.sh" "Failed to pushd"
        exit 16
    fi

    "$SCRIPT_DIR/echo-step.sh" "Normalizing file permissions on ${plugin_folder}"
    find ./${plugin_folder} -type f -exec chmod 644 {} \;
    find ./${plugin_folder} -type d -exec chmod 755 {} \;

    "$SCRIPT_DIR/echo-step.sh" "Creating the zip file on ${zip_path} with normalized permissions"
    if ! zip -qr "${zip_path}" ./${plugin_folder}; then
        "$SCRIPT_DIR/echo-error.sh" "Failed to create zip file"
        exit 17
    fi
    if ! popd >/dev/null 2>&1; then
        "$SCRIPT_DIR/echo-error.sh" "Failed to popd"
        exit 18
    fi

    "$SCRIPT_DIR/echo-command-header.sh" "Verifying the zip file ${zip_path}"
    if [ ! -f "${zip_path}" ]; then
        "$SCRIPT_DIR/echo-error.sh" "Zip file ${zip_path} does not exist"
        exit 19
    else
        "$SCRIPT_DIR/echo-step.sh" "Asserting that zip file ${zip_path} exists"
        "$SCRIPT_DIR/echo-step.sh" "Listing the zip file ${zip_path}"
        echo ""
        run_indented 20 ls -lha "${zip_path}"
    fi
}

case "${command}" in
"dir")
    "$SCRIPT_DIR/set-git-config.sh" "${source_path}"
    command_dir

    "$SCRIPT_DIR/echo-separator.sh"
    show_elapsed_time
    echo ""

    echo "🎉" " Executed successfully!"
    echo ""
    exit 0
    ;;
"zip")
    "$SCRIPT_DIR/set-git-config.sh" "${source_path}"
    command_dir
    command_zip

    "$SCRIPT_DIR/echo-separator.sh"
    show_elapsed_time
    echo ""

    echo "🎉" " Executed successfully!"
    echo ""
    exit 0
    ;;
"clean")
    "$SCRIPT_DIR/echo-command-header.sh" "Cleaning dist directory"
    "$SCRIPT_DIR/clean-dist.sh" "${tmp_build_dir}"

    "$SCRIPT_DIR/echo-separator.sh"
    show_elapsed_time
    echo ""

    echo "🎉" " Executed successfully!"
    echo ""
    exit 0
    ;;
"version")
    "$SCRIPT_DIR/echo-command-header.sh" "Getting plugin version"
    echo "${plugin_version}" > version.txt

    "$SCRIPT_DIR/echo-separator.sh"
    show_elapsed_time
    echo ""

    echo "🎉" " Executed successfully!"
    echo ""
    exit 0
    ;;
*)
    "$SCRIPT_DIR/echo-error.sh" "invalid option ${command}"
    "$SCRIPT_DIR/echo-separator.sh"
    echo ""
    show_help
    show_elapsed_time
    echo ""
    echo "⚠️  Error: Command '${command}' failed or is invalid. Please check your input and try again."
    echo ""
    exit 1
    ;;
esac
