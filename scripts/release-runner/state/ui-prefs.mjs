import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, resolve } from 'path';

const THEMES = ['light', 'dark'];

/**
 * @param {string} [cwd]
 */
export function getUiPrefsPath(cwd = process.cwd()) {
  return resolve(cwd, 'dev-workspace-cache/release-runner-ui.json');
}

/**
 * Page preferences. Unknown or invalid values are dropped.
 * `autoRun` defaults to on when missing: auto steps chain until the next gate.
 *
 * @param {string} [cwd]
 * @returns {{ theme?: 'light' | 'dark', autoRun?: boolean }}
 */
export function loadUiPrefs(cwd = process.cwd()) {
  const path = getUiPrefsPath(cwd);
  if (!existsSync(path)) {
    return {};
  }
  try {
    const data = JSON.parse(readFileSync(path, 'utf8'));
    /** @type {{ theme?: 'light' | 'dark', autoRun?: boolean }} */
    const prefs = {};
    if (THEMES.includes(data?.theme)) {
      prefs.theme = data.theme;
    }
    if (typeof data?.autoRun === 'boolean') {
      prefs.autoRun = data.autoRun;
    }
    return prefs;
  } catch {
    return {};
  }
}

/**
 * Merge one preference. Omit a key to leave it unchanged.
 *
 * @param {{ theme?: string, autoRun?: boolean }} patch
 * @param {string} [cwd]
 * @returns {{ theme?: 'light' | 'dark', autoRun?: boolean }}
 */
export function saveUiPrefs(patch, cwd = process.cwd()) {
  const prefs = { ...loadUiPrefs(cwd) };
  if (patch?.theme !== undefined) {
    if (!THEMES.includes(patch.theme)) {
      throw new Error(`Invalid theme: ${patch.theme}. Use light or dark.`);
    }
    prefs.theme = patch.theme;
  }
  if (patch?.autoRun !== undefined) {
    if (typeof patch.autoRun !== 'boolean') {
      throw new Error('Invalid autoRun: expected true or false.');
    }
    prefs.autoRun = patch.autoRun;
  }
  if (patch?.theme === undefined && patch?.autoRun === undefined) {
    throw new Error('No UI preference to save.');
  }
  const path = getUiPrefsPath(cwd);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(prefs, null, 2)}\n`);
  return prefs;
}
