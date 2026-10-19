import { mkdtempSync, readFileSync, rmSync, writeFileSync, mkdirSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getUiPrefsPath, loadUiPrefs, saveUiPrefs } from '../scripts/release-runner/state/ui-prefs.mjs';

test('theme is saved in dev-workspace-cache and read back', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-ui-'));
  try {
    assert.deepEqual(loadUiPrefs(cwd), {});
    saveUiPrefs({ theme: 'dark' }, cwd);
    assert.equal(getUiPrefsPath(cwd), join(cwd, 'dev-workspace-cache/release-runner-ui.json'));
    assert.deepEqual(JSON.parse(readFileSync(getUiPrefsPath(cwd), 'utf8')), { theme: 'dark' });
    assert.deepEqual(loadUiPrefs(cwd), { theme: 'dark' });
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('autoRun is saved without dropping the theme', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-ui-'));
  try {
    saveUiPrefs({ theme: 'dark' }, cwd);
    saveUiPrefs({ autoRun: false }, cwd);
    assert.deepEqual(loadUiPrefs(cwd), { theme: 'dark', autoRun: false });
    saveUiPrefs({ autoRun: true }, cwd);
    assert.equal(loadUiPrefs(cwd).autoRun, true);
    assert.equal(loadUiPrefs(cwd).theme, 'dark');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('invalid autoRun is rejected on save and ignored on load', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-ui-'));
  try {
    assert.throws(() => saveUiPrefs({ autoRun: 'no' }, cwd), /Invalid autoRun/);
    mkdirSync(join(cwd, 'dev-workspace-cache'), { recursive: true });
    writeFileSync(getUiPrefsPath(cwd), '{"autoRun":"off","theme":"light"}');
    assert.deepEqual(loadUiPrefs(cwd), { theme: 'light' });
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('invalid themes are rejected on save and ignored on load', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-ui-'));
  try {
    assert.throws(() => saveUiPrefs({ theme: 'blue' }, cwd), /Invalid theme/);
    mkdirSync(join(cwd, 'dev-workspace-cache'), { recursive: true });
    writeFileSync(getUiPrefsPath(cwd), '{"theme":"\\"><script>"}');
    assert.deepEqual(loadUiPrefs(cwd), {});
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});
