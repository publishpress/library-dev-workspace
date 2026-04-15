# PublishPress Dev Workspace

Shared development tooling for PublishPress WordPress plugins. This Composer package exposes scripts for building, testing, translating, syncing, and quality checks — all managed through standard `composer` commands.

## What it provides

- **Docker** — Compose setup for local development and automated tests
- **Build & pack** — JavaScript (webpack), zip/dir packaging, version helpers
- **Quality** — PHP compatibility, PHPCS, phplint, PHPStan, PHP-CS-Fixer
- **Tests** — Codeception workflows and Docker test stack helpers
- **i18n** — POT/MO/JSON/PHP translation pipelines and PublishPress Translate hooks
- **Sync** — Optional rsync to local or remote WordPress installs

## Installing in a plugin

This package is a [Composer plugin](https://getcomposer.org/doc/articles/plugins.md), so it must be explicitly allowed in `config.allow-plugins` before Composer will activate it.

Add the following to the plugin's `composer.json` first, then run `composer update`:

```json
{
    "require-dev": {
        "publishpress/dev-workspace": "^1.0"
    },
    "config": {
        "allow-plugins": {
            "publishpress/dev-workspace": true,
            "php-http/discovery": true,
            "dealerdirect/phpcodesniffer-composer-installer": true,
            "phpstan/extension-installer": true
        }
    }
}
```

Once installed, all shared scripts become available through `composer`. For example:

```bash
composer build
composer test:up
composer check:all
```

If the plugin already defined those commands under `scripts` in its own `composer.json`, remove them. Names such as `build`, `check:php`, `check:all`, `test:up`, and the other shared workflows are registered by this package; keeping copies in the plugin would shadow or duplicate what the workspace provides.

If the project root still has a `dev-workspace` file delete it entirely. Tooling is installed under `vendor/publishpress/dev-workspace`; leaving the old path in place can confuse editors, scripts, or sync rules that treat `dev-workspace` as a separate tree.

### Remove duplicate Composer dependencies

This package already **requires** the shared QA and test stack. After adding `publishpress/dev-workspace`, drop the same packages from the plugin’s own `require-dev` (and from `require` if they were only there for tooling) so you do not pin conflicting versions or install duplicates. Typical overlaps include:

- **PHPCS ecosystem** — `squizlabs/php_codesniffer`, `dealerdirect/phpcodesniffer-composer-installer`, `wp-coding-standards/wpcs`, `automattic/vipwpcs`, `phpcompatibility/php-compatibility`, `publishpress/publishpress-phpcs-standards`
- **Static analysis and fixes** — `phpstan/phpstan`, `phpstan/extension-installer`, `szepeviktor/phpstan-wordpress`, `friendsofphp/php-cs-fixer`, `overtrue/phplint`, `phpmd/phpmd`, `phpmetrics/phpmetrics`
- **Tests** — Codeception modules, `lucatume/wp-browser`, `behat/behat`, `phpunit/phpunit`, and related packages pulled in for acceptance tests
- **CLI and i18n** — `wp-cli/wp-cli-bundle`, `wp-cli/i18n-command`
- **Other dev tools** — e.g. `publishpress/translations`, `knplabs/github-api` with PSR-7 HTTP, `spatie/ray`, `symfony/process`

The complete and current list is the `require` section of this repository’s `composer.json`:

[github.com/publishpress/dev-workspace/blob/development/composer.json](https://github.com/publishpress/dev-workspace/blob/development/composer.json)

Keep any dependency the plugin needs **at runtime** or that is **not** provided by `dev-workspace`. After edits, run `composer update` and fix anything that still expects binaries under the plugin’s direct `vendor/bin` paths (prefer `composer` script names or `vendor/bin/...` as resolved from the root install).

### Configuring the plugin metadata

Set the following keys in the plugin's `composer.json` `extra` section so the workspace can expose the right environment variables to scripts:

```json
{
    "extra": {
        "plugin-slug": "post-expirator",
        "plugin-name": "publishpress-future",
        "plugin-folder": "post-expirator",
        "version-constant": "PUBLISHPRESS_FUTURE_VERSION",
        "plugin-lang-domain": "post-expirator",
        "plugin-github-repo": "publishpress/publishpress-future",
        "plugin-composer-package": "publishpress/publishpress-future"
    }
}
```

Each plugin root must have two environment files:

- **`.env.example`** — committed template with placeholder or default values; keep it in the repository so contributors know what variables are required.
- **`.env`** — your local copy with real values; never commit it (add `.env` to `.gitignore`).

The canonical reference for all keys and their expected format is the fake-plugin template in this repository:

[github.com/publishpress/dev-workspace/blob/development/test/fake-plugin/.env.example](https://github.com/publishpress/dev-workspace/blob/development/test/fake-plugin/.env.example)

Copy that file into the plugin root, rename it to `.env.example`, and fill in the values for your plugin. At minimum, set:

```bash
PLUGIN_NAME="PublishPress Future"
PLUGIN_TYPE="FREE"
PLUGIN_COMPOSER_PACKAGE="publishpress/publishpress-future"

TERMINAL_IMAGE_NAME="publishpress/dev-workspace-terminal:node-25"
WP_IMAGE_NAME="publishpress/dev-workspace-wordpress:wordpress-6.9-php-8.5"
WPCLI_IMAGE_NAME="publishpress/dev-workspace-wpcli:wpcli-2-php-8.5"
```

`PLUGIN_TYPE` is typically `FREE` or `PRO`. `PLUGIN_COMPOSER_PACKAGE` must match the package name in the plugin’s `composer.json` (and the `plugin-composer-package` value under `extra` when you set it). Adjust `PLUGIN_NAME` to the human-readable product name.

Use the **same** `TERMINAL_IMAGE_NAME`, `WP_IMAGE_NAME`, and `WPCLI_IMAGE_NAME` values in every plugin; do not use per-plugin image tags. When these images are updated in `dev-workspace`, bump the tags here in `.env.example` (and your local `.env`) together with any release notes from this package.

After editing `.env.example`, copy it to `.env`.

Both `.env` and `.env.example` must be excluded from the built/distributed package. They are already listed in `.rsync-filters-pre-build.default` and `.rsync-filters-post-build.default` (the rsync filter files used during packaging), so no extra action is required as long as the plugin uses the standard build pipeline from this package.

### `dev-workspace-cache` directory

Tools from this package create a `dev-workspace-cache` folder at the project root (or the path set by `CACHE_PATH` in `.env`). It holds local-only data: Docker volume data (for example WordPress and MySQL test instances), npm and shell caches inside containers, deploy debug logs, and similar artifacts. It is regenerated as needed and must not be committed.

Add it to the plugin repository’s `.gitignore`:

```
dev-workspace-cache/
```

It is also excluded from the built/distributed package — it is listed in both `.rsync-filters-pre-build.default` and `.rsync-filters-post-build.default`, so no extra action is required when using the standard build pipeline.

### Docker image cleanup

Older setups used **per-plugin image tags** (for example `publishpress/dev-workspace-terminal:publishpress-revisions`). All PublishPress plugins are expected to use the **same shared images** set via `TERMINAL_IMAGE_NAME`, `WP_IMAGE_NAME`, and `WPCLI_IMAGE_NAME` in `.env` (see the environment files section above).

You can reclaim disk space by listing and removing obsolete images that are named or tagged after a single plugin:

```bash
docker image ls 'publishpress/dev-workspace*'
docker rmi publishpress/dev-workspace-terminal:publishpress-revisions   # example; use your actual unused tags
```

Use `docker image prune` or `docker system prune` if you want a broader cleanup; only remove images you no longer need.

## Entering the development shell

To open an interactive terminal inside the development container, run:

```bash
composer dev:shell
```

This replaces the legacy `dev-workspace/run` script. If you still have that file in your project root, delete it — the command above is the only supported entry point.

## Requirements

- Composer 2.x
- PHP with the following extensions enabled (Composer and tooling expect them to be available):
  - **ext-dom** — XML/HTML DOM (used by tooling that parses or generates markup)
  - **ext-curl** — HTTP client support (used by packages and scripts that perform outbound requests)
- Docker (for container-based scripts and tests)

## License

GPL-2.0-or-later (see `LICENSE`).
