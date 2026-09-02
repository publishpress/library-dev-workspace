# PublishPress Dev Workspace

Shared Docker, Composer, and shell tooling used to build, test, translate, and release PublishPress WordPress plugins.

## Language

**Version constant**:
A PHP `define()` holding the plugin semver, named by `composer.json` → `extra.version-constant`.
_Avoid_: version define, VERSION define (when referring to this specific metadata field)

**Version constant candidate file**:
One of the plugin-root files where the version constant may live: the main plugin file (`{slug}.php`), `defines.php`, `constants.php`, or `include.php`.
_Avoid_: constants file (generic), config file

**Canonical version constant location**:
Exactly one version constant candidate file contains the define for a plugin. Zero or multiple locations fail release checks and version bump.
_Avoid_: primary constant file, source of truth file

## Relationships

- A plugin declares its **version constant** name in `composer.json` → `extra.version-constant`
- The **version constant** must exist in exactly one **version constant candidate file**
- `check-release`, `check-wporg`, and `plugin-bump-version` all enforce the same candidate list and exactly-one-file rule

## Example dialogue

> **Dev:** "Future stores `PUBLISHPRESS_FUTURE_VERSION` in `defines.php`, not the main plugin file. Will `check:release` pass?"
> **Maintainer:** "Yes — as long as `defines.php` is the only candidate file that defines it. The main file still carries the Version header; the constant must not also appear there."

## Flagged ambiguities

- "version" alone can mean the plugin header, readme Stable tag, package.json field, or version constant — use the specific term above when discussing constant placement.
