import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  getPreset,
  getPresetMeta,
  normalizeEdition,
  parseEditionInput,
  PRESET_PLUGIN_FREE_STABLE,
  PRESET_PLUGIN_FREE_UNSTABLE,
  PRESET_PLUGIN_PRO_STABLE,
  PRESET_PLUGIN_PRO_UNSTABLE,
} from '../scripts/release-runner/presets/index.mjs';

test('getPresetMeta defines labels and version rules per preset', () => {
  assert.equal(getPresetMeta(PRESET_PLUGIN_FREE_STABLE).label, 'Stable');
  assert.equal(getPresetMeta(PRESET_PLUGIN_FREE_STABLE).product, 'free');
  assert.equal(getPresetMeta(PRESET_PLUGIN_PRO_STABLE).label, 'Stable');
  assert.equal(getPresetMeta(PRESET_PLUGIN_FREE_UNSTABLE).label, 'Prerelease');
  assert.equal(getPresetMeta(PRESET_PLUGIN_PRO_STABLE).product, 'pro');
  assert.equal(getPresetMeta(PRESET_PLUGIN_FREE_STABLE).versionRule, 'stable');
  assert.equal(getPresetMeta(PRESET_PLUGIN_FREE_UNSTABLE).versionRule, 'prerelease');
  assert.deepEqual(getPresetMeta(PRESET_PLUGIN_FREE_UNSTABLE).channels, ['beta', 'rc']);
});

test('normalizeEdition maps legacy aliases to stable presets', () => {
  assert.equal(normalizeEdition('free'), PRESET_PLUGIN_FREE_STABLE);
  assert.equal(normalizeEdition('pro'), PRESET_PLUGIN_PRO_STABLE);
});

test('parseEditionInput accepts all plugin preset ids', () => {
  assert.equal(parseEditionInput('plugin-free-unstable'), PRESET_PLUGIN_FREE_UNSTABLE);
  assert.equal(parseEditionInput('plugin-pro-unstable'), PRESET_PLUGIN_PRO_UNSTABLE);
});

test('plugin-free-unstable omits milestone and post-release gates', () => {
  const ids = getPreset(PRESET_PLUGIN_FREE_UNSTABLE).map((s) => s.id);
  assert.ok(!ids.includes('milestone_check'));
  assert.ok(!ids.includes('milestone_close'));
  assert.ok(!ids.includes('post_release'));
  assert.ok(!ids.includes('check_wporg'));
  assert.ok(ids.includes('github_release'));
});

test('plugin-pro-unstable omits milestone steps', () => {
  const ids = getPreset(PRESET_PLUGIN_PRO_UNSTABLE).map((s) => s.id);
  assert.ok(!ids.includes('milestone_check'));
  assert.ok(!ids.includes('milestone_close'));
  assert.ok(ids.includes('package_server_check'));
});

test('unstable presets omit translation work and the stable release gate', () => {
  const skipped = ['translate_ai', 'translate_commit', 'wait_translator_es_fr_it',
    'wait_translator_pt_br', 'translate_download', 'translate_compile',
    'changelog_i18n', 'check_release'];
  for (const preset of [PRESET_PLUGIN_FREE_UNSTABLE, PRESET_PLUGIN_PRO_UNSTABLE]) {
    const ids = getPreset(preset).map(step => step.id);
    for (const id of skipped) assert.ok(!ids.includes(id), `${preset}: ${id}`);
  }
  for (const preset of [PRESET_PLUGIN_FREE_STABLE, PRESET_PLUGIN_PRO_STABLE]) {
    const ids = getPreset(preset).map(step => step.id);
    for (const id of skipped) assert.ok(ids.includes(id), `${preset}: ${id}`);
  }
});
