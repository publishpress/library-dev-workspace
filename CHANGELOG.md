# Changelog

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

[1.1.7] - 15 April, 2026

- Changed: Updated the default post-build rsync filters to exclude all `.env*` files.
- Changed: Unified and improved the `.env.example` template in the `test/fake-plugin` directory for consistency.

[1.1.6] - 14 April, 2026

- Added: Introduced the `translate:audit` command, leveraging `wp i18n audit` to identify issues in translation files.
- Changed: Updated `composer.json` to set the minimum stability to `dev`.
- Changed: Updated the `translate` command to automatically run `translate:compile` at the end.
- Changed: The `translate` command now uses all default languages automatically, removing the need to specify the LANG_LOCALES argument.
- Changed: JSON translation generation can now be enabled by setting the GENERATE_TRANSLATION_JSON environment variable.

[1.1.5] - 08 April, 2026

- Fixed: Added an environment variable to control JSON translation generation; it is now disabled by default.

[1.1.4] - 07 April, 2026

- Changed: Display the destination path in the output of the local-sync.sh script.

[1.1.3] - 03 April, 2026

- Fixed: Docker service ports (db_test, mailhog) are now configurable via environment variables (`DB_TESTS_PORT`, `MAILHOG_WEB_PORT`, `MAILHOG_SMTP_PORT`) with backward-compatible defaults.
- Fixed: All `docker compose` commands now explicitly pass `--env-file` to ensure the plugin's `.env` is always used for variable interpolation.
- Fixed: Replaced individual file bind mounts for mu-plugins and ray.php with file copies into the cache directory, fixing "mountpoint outside of rootfs" errors on Docker Desktop for Mac with virtiofs.
- Added: Integration and unit test scaffolding for the fake-plugin test project.

[1.1.2] - 03 April, 2026

- Fixed: Enhanced management of mounted files and directories to avoid write errors affecting the global git configuration and zsh history files.

[1.1.1] - 03 April, 2026

- Fixed: Updated composer.json to set the PHP_CodeSniffer config path to the vendor directory and refreshed composer.lock to update the content hash.

[1.1.0] - 02 April, 2026

- Changed: Added all essential dependencies and libraries.

[1.0.1] - 02 April, 2026

- Fixed: Fix cache path for NPM, Composer and ZSH history in the dev shell.

[1.0.0] - 01 April, 2026

First release
