# Run inside the dev-workspace terminal (BusyBox sh). Not executed on the host.
# docker passes this file as `sh -c` with the user command in "$@".
#
# Composer path repositories make vendor/publishpress/dev-workspace a symlink
# to a directory outside the plugin checkout. The plugin mount keeps that
# symlink, and Docker will not replace a symlink with a bind mount, so the
# vendor path is missing inside the container. The real package is mounted
# at /opt/dev-workspace; rewrite those command paths when the vendor copy
# is not a directory.

project_dir="${CONTAINER_PROJECT_DIR:-/project}"
mount_dir="${DEV_WORKSPACE_MOUNT:-/opt/dev-workspace}"
vendor_dir="vendor/publishpress/dev-workspace"

export DEV_WORKSPACE_DIR="$project_dir/$vendor_dir"
export PATH="$DEV_WORKSPACE_DIR/scripts:$mount_dir/scripts:$PATH"
cd "$project_dir" || exit 1

if [ ! -d "$vendor_dir/scripts" ] && [ -d "$mount_dir/scripts" ]; then
    for arg do
        case "$arg" in
            vendor/publishpress/dev-workspace/*)
                arg="$mount_dir/${arg#vendor/publishpress/dev-workspace/}"
                ;;
        esac
        set -- "$@" "$arg"
        shift
    done
    export DEV_WORKSPACE_DIR="$mount_dir"
    export PATH="$mount_dir/scripts:$PATH"
fi

if [ -n "${GIT_USER_NAME:-}" ]; then
    git config --global user.name "$GIT_USER_NAME"
fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
fi

exec "$@"
