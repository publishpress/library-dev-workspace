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
      "publishpress/dev-workspace": true
    }
  }
}
```

Alternatively, use the CLI — Composer will prompt you to allow the plugin on first install:

```bash
composer require --dev publishpress/dev-workspace
```
```

Once installed, all shared scripts become available through `composer`. For example:

```bash
composer build
composer test:up
composer check:all
```

### Configuring the plugin metadata

Set the following keys in the plugin's `composer.json` `extra` section so the workspace can expose the right environment variables to scripts:

```json
{
  "extra": {
    "plugin-slug": "my-plugin",
    "plugin-lang-domain": "my-plugin",
    "plugin-github-repo": "publishpress/my-plugin",
    "plugin-composer-package": "publishpress/my-plugin"
  }
}
```

Copy `.env.example` to `.env` at the plugin root and adjust values for Docker and sync settings.

## Requirements

- Composer 2.x
- Docker (for container-based scripts and tests)

## License

GPL-2.0-or-later (see `LICENSE`).
