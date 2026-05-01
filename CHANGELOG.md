# Changelog

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

[UNRELEASED]

- Added: Upgraded the translator library and introduced the `composer translate:audit` and `composer translate:audit-report` commands for comprehensive language translation auditing.

[1.2.2] - 30 April, 2026

- Changed: No longer require `OPENAI_API_KEY`, `WEBLATE_API_TOKEN`, and `WEBLATE_API_URL` as mandatory environment variables.

[1.2.1] - 30 April, 2026

- Changed: Renamed `env-init.sh` to `env-bootstrap.sh` for clearer script purpose and consistency.
- Changed: Now requires both `LANG_LOCALES` and `PLUGIN_NAME` to be set in the `.env` file.
- Changed: Added missing help instructions for available commands to improve usability.
- Changed: Output formatting for all commands has been standardized for clarity and consistency.

[1.2.0] - 29 April, 2026

- Added: New script `plugin-metadata-github-output.sh` to extract plugin metadata from the Composer file and export it for use as GitHub Actions outputs.
- Added: Introduced dedicated scripts for generating `.mo`, `.php`, and `.pot` files: `translate-mo.sh`, `translate-php.sh`, and `translate-pot.sh`.
- Changed: Renamed `lang-make-json.sh` to `translate-json.sh` for clarity.
- Changed: Streamlined and clarified the builder script header output.
- Changed: Refactored compiled file generation to process each language individually, with improved progress feedback and early exit if any file is missing or an error occurs.
- Fixed: Resolved inconsistent generation of compiled files—ensuring all `.php`, `.json`, and `.mo` files are reliably created.

[1.1.9] - 22 April, 2026

- Added: Introduced the `translate:repair` command in composer.json to automatically fix pluralization issues in translation files.

[1.1.8] - 17 April, 2026

- Fixed: Ensure the `.gitconfig` cache path is always a regular file during cache init, preventing Docker Desktop/WSL bind-mount errors ("not a directory" for `/root/.gitconfig`).
- Fixed: Normalize git config cache paths for legacy and current mounts.
- Fixed: Enforce LF line endings for shell scripts on Windows by adding a `.gitattributes` rule.
- Fixed: Source `env-init.sh` in `lang-make-json.sh` and `translate-locales.sh` to ensure `LANG_LOCALES` is properly set before execution.
- Changed: Export `DEFAULT_LANG_LOCALES` from `env-init.sh` and refactor `LANG_LOCALES` handling in `translate-locales.sh` for improved consistency.
- Changed: Update script commands in `composer.json` to use `bash` for execution and remove unused Codeception module.
- Changed: Make `spaces-to-csv.sh` and `translate-locales.sh` executable.
- Added: Document GitHub authentication setup in README, including personal access token creation and Composer configuration to avoid API rate limits.

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
