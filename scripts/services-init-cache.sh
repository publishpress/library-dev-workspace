#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-init.sh"

# If the legacy dir "cache" exists, move its content to $CACHE_PATH and remove it.
if [[ -d "cache" ]]; then
    mv cache/* $CACHE_PATH
    rm -rf cache
fi

# Create empty cache files if not exists.
[[ -d $CACHE_PATH ]] || mkdir -p $CACHE_PATH
[[ -d $CACHE_PATH/.npm/_cacache ]] || mkdir -p $CACHE_PATH/.npm/_cacache
[[ -d $CACHE_PATH/.npm/_logs ]] || mkdir -p $CACHE_PATH/.npm/_logs
[[ -d $CACHE_PATH/.composer/cache ]] || mkdir -p $CACHE_PATH/.composer/cache
[[ -d $CACHE_PATH/.oh-my-zsh/log ]] || mkdir -p $CACHE_PATH/.oh-my-zsh/log
# Backward compatibility for older mount layout that binds
# $CACHE_PATH/.git/config to /root/.gitconfig.
if [[ -e "$CACHE_PATH/.git" && ! -d "$CACHE_PATH/.git" ]]; then
    rm -rf "$CACHE_PATH/.git"
fi
[[ -d $CACHE_PATH/.git ]] || mkdir -p $CACHE_PATH/.git
if [[ -e "$CACHE_PATH/.git/config" && ! -f "$CACHE_PATH/.git/config" ]]; then
    rm -rf "$CACHE_PATH/.git/config"
fi
[[ -f $CACHE_PATH/.git/config ]] || touch $CACHE_PATH/.git/config

# Current mount layout uses $CACHE_PATH/.gitconfig as a directory volume.
if [[ -e "$CACHE_PATH/.gitconfig" && ! -d "$CACHE_PATH/.gitconfig" ]]; then
    rm -rf "$CACHE_PATH/.gitconfig"
fi
[[ -d $CACHE_PATH/.gitconfig ]] || mkdir -p $CACHE_PATH/.gitconfig
# Recover from stale cache state where config was created with the wrong type.
if [[ -e "$CACHE_PATH/.gitconfig/config" && ! -f "$CACHE_PATH/.gitconfig/config" ]]; then
    rm -rf "$CACHE_PATH/.gitconfig/config"
fi
# Docker bind-mount directories for test containers must be pre-created by the host user
# so containers (mariadb, wordpress) get correct ownership on first start.
[[ -d $CACHE_PATH/db_test ]] || mkdir -p $CACHE_PATH/db_test
[[ -d $CACHE_PATH/logs/db_test ]] || mkdir -p $CACHE_PATH/logs/db_test
[[ -d $CACHE_PATH/wp_test/wp-content/mu-plugins ]] || mkdir -p $CACHE_PATH/wp_test/wp-content/mu-plugins
# Copy mu-plugin and ray files into the WP cache so they are part of the main
# volume mount. Mounting individual files inside an already-mounted directory
# fails on Docker Desktop for Mac with virtiofs.
[[ -f "$DEV_WORKSPACE_DIR/docker/wp/wordpress/mu-plugins/load-spatie-ray.php" ]] && cp -f "$DEV_WORKSPACE_DIR/docker/wp/wordpress/mu-plugins/load-spatie-ray.php" "$CACHE_PATH/wp_test/wp-content/mu-plugins/load-spatie-ray.php"
[[ -f "$DEV_WORKSPACE_DIR/docker/wp/wordpress/mu-plugins/pp-mailhog.php" ]] && cp -f "$DEV_WORKSPACE_DIR/docker/wp/wordpress/mu-plugins/pp-mailhog.php" "$CACHE_PATH/wp_test/wp-content/mu-plugins/pp-mailhog.php"
[[ -f "$DEV_WORKSPACE_DIR/docker/wp/wordpress/ray.php" ]] && cp -f "$DEV_WORKSPACE_DIR/docker/wp/wordpress/ray.php" "$CACHE_PATH/wp_test/ray.php"
[[ -d $CACHE_PATH/.zsh ]] || mkdir -p $CACHE_PATH/.zsh
[[ -f $CACHE_PATH/.zsh/.zsh_history ]] || touch $CACHE_PATH/.zsh/.zsh_history
[[ -f $CACHE_PATH/.bash_history ]] || touch $CACHE_PATH/.bash_history
[[ -f $CACHE_PATH/.composer/auth.json ]] || echo '{}' > $CACHE_PATH/.composer/auth.json
[[ -f $CACHE_PATH/.gitconfig/config ]] || touch $CACHE_PATH/.gitconfig/config
