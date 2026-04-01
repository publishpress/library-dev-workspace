# Changelog

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

[1.0.2] - 01 April, 2026

- Fixed: Fixed `REPO_ROOT` calculation in `scripts/env-init.sh` overshooting the project root by one directory level when the package is installed via Composer at `vendor/publishpress/dev-workspace`. The traversal was corrected from `../../../..` (4 levels) to `../../..` (3 levels), resolving the `.env file not found` error on every `composer` command.

[1.0.1] - 01 April, 2026

- Fixed: Fixed paths in `composer.json`, `docker/compose.yaml`, and shell scripts to use `vendor/publishpress/dev-workspace` instead of a root-level `dev-workspace` directory.

[1.0.0] - 01 April, 2026

- First release.
