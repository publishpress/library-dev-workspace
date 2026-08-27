---
name: release-dev-workspace
description: >-
  Release publishpress/dev-workspace (library-dev-workspace) predictably:
  finalize CHANGELOG, bump DEV_WORKSPACE_VERSION, commit, tag, push, and
  create the GitHub release. Use when releasing this package, cutting a
  new x.y.z tag, publishing to Packagist, or the user asks to release
  / bump / ship dev-workspace.
---

# Release publishpress/dev-workspace

Repo: `publishpress/library-dev-workspace` (local folder often `dev-workspace`).
Package: `publishpress/dev-workspace` on Packagist. Tags drive Packagist — **no** plugin-style `composer set:version`.

## When

- User asks to release / ship / tag / bump this package
- After merging feature work on `master` (or agreed release branch)
- Before telling consuming plugins to `composer update publishpress/dev-workspace`

## Hard rules

1. Work in the **dev-workspace git root**, not a plugin that vendors it.
2. Every release: **CHANGELOG section with date** + **`DEV_WORKSPACE_VERSION` in `docker/compose.yaml`** must match the tag.
3. Tag = version string only (`1.8.4`), no `v` prefix (match existing tags).
4. Do **not** leave `[Unreleased]` bullets unpublished — move them into the version section.
5. After tag + GitHub release, consumers get the version from Packagist (may lag a few minutes).

## Version choice

| Change type | Bump |
|-------------|------|
| Patch / docs / skill / small fix | `x.y.Z` |
| New scripts / behavior change (backward compatible) | `x.Y.0` |
| Breaking for consumers | `X.0.0` |

Read latest tag: `git tag --sort=-v:refname | head -5`

## Checklist (do in order)

### 1. Inspect tree

```bash
git status
git diff
git log -5 --oneline
git tag --sort=-v:refname | head -5
```

Confirm intended commits are on the release branch (`master` unless user says otherwise).

### 2. Finalize CHANGELOG.md

Format (Keep a Changelog + this repo’s date style):

```markdown
[VERSION] - DD Mmm, YYYY

- Type: Imperative summary.
```

- Date: `12 Aug, 2026` style (day + 3-letter month + comma + year)
- Always include: `Changed: Builder/terminal DEV_WORKSPACE_VERSION in docker/compose.yaml updated to VERSION.`
- Types used here: `Added`, `Changed`, `Fixed`, `Removed`
- If an undated `[VERSION]` stub exists, only add the date + any missing bullets

### 3. Bump compose version

In `docker/compose.yaml` (terminal service `environment`):

```yaml
DEV_WORKSPACE_VERSION: "VERSION"
```

Must equal the tag / CHANGELOG version.

### 4. Commit

Prefer two commits when both feature + release prep are unstaged; one commit is fine if only release metadata remains:

```text
chore(release): prepare VERSION changelog and compose version
```

Conventional Commits; no AI attribution; no file laundry list.

### 5. Push, tag, GitHub release

```bash
git push origin HEAD
git tag -a VERSION -m "VERSION"
git push origin VERSION
gh release create VERSION --title "VERSION" --notes "$(cat <<'EOF'
# Changelog

- …same bullets as CHANGELOG section (omit the compose-version-only line if redundant)…
EOF
)"
```

Verify: `gh release view VERSION` and `git status` clean / up to date.

### 6. Tell the user

- Release URL
- Remind: plugins need `composer update publishpress/dev-workspace` (constraint allowing VERSION)
- Path-repo / symlink local testing is optional and **not** part of the shipped release

## Related consumer gates (do not confuse)

These live **in plugins** that require this package — not this release ritual:

| Command | Role |
|---------|------|
| `composer check:release` | Pre-release gate on **plugin source** (stable `x.y.z` only) |
| `composer check:release-if-stable` | Same, but **skips** beta/rc/alpha (`--if-stable`) |
| `composer build` | Runs `check:release-if-stable` on project root, then `pack:zip` |
| `composer check:wporg` | Post wordpress.org deploy verification |

Beta versions must look like `4.10.5-beta.1` (also `alpha` / `rc`). Build still packs; the release gate skips.

Optional: `check-release.sh [PATH] [VERSION]` — default PATH is project root. Build does **not** check `dist/`.

## Common mistakes (avoid)

- Tagging without bumping `DEV_WORKSPACE_VERSION` (Packagist consumers see stale compose metadata in the package)
- CHANGELOG entry without a date
- Releasing from a plugin checkout instead of this library repo
- Expecting `composer build` inside **this** repo to be the library release step (build scripts are for **consuming plugins**)
- Amending / force-pushing tags already on Packagist — cut a new patch version instead (see 1.8.2 history)

## Example (1.8.4)

1. CHANGELOG → `[1.8.4] - 12 Aug, 2026` + bullets  
2. `DEV_WORKSPACE_VERSION: "1.8.4"`  
3. Commit → push `master` → tag `1.8.4` → `gh release create 1.8.4`  
4. Plugins: `composer update publishpress/dev-workspace`
