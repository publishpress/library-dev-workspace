import { mkdtempSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { commands } from '../scripts/release-runner/cli.mjs';
import { createReleaseRecord, loadCurrentRelease, saveRelease } from '../scripts/release-runner/state/store.mjs';
import { fixturePreset } from '../scripts/release-runner/presets/fixture.mjs';
import { runEngine, cascadeReopen } from '../scripts/release-runner/engine/engine.mjs';

test('stepwise runs one auto step and leaves the next pending', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    const release = createReleaseRecord('1.0.0', 'fixture', 'standard', fixturePreset);
    release.edition = 'fixture';
    saveRelease(release, cwd);

    const result = await runEngine(release, { cwd, stepwise: true });
    assert.equal(result.exitCode, 0);
    assert.equal(result.release.steps.auto_ok.status, 'done');
    assert.equal(result.release.steps.auto_next.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('confirm with stepwise does not run the following auto step', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    const release = createReleaseRecord('1.0.0', 'fixture', 'standard', fixturePreset);
    release.edition = 'fixture';
    release.steps.auto_ok = { status: 'done', at: new Date().toISOString() };
    release.steps.auto_next = { status: 'done', at: new Date().toISOString() };
    release.steps.manual_gate = { status: 'done', at: new Date().toISOString() };
    saveRelease(release, cwd);

    const result = await runEngine(release, { cwd, confirm: 'confirm_gate', stepwise: true });
    assert.equal(result.release.steps.confirm_gate.status, 'done');
    assert.equal(result.release.steps.auto_final.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('run with autoRun false stops after one auto step', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    const release = createReleaseRecord('1.0.0', 'fixture', 'standard', fixturePreset);
    release.edition = 'fixture';
    saveRelease(release, cwd);

    const code = await commands.run([], cwd, { json: false, yes: false, autoRun: false });
    const loaded = loadCurrentRelease(cwd);
    assert.equal(code, 0);
    assert.equal(loaded.steps.auto_ok.status, 'done');
    assert.equal(loaded.steps.auto_next.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('run stops on manual gate with exit 10', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    let release = createReleaseRecord('1.0.0', 'fixture', 'standard', fixturePreset);
    release.edition = 'fixture';
    saveRelease(release, cwd);

    const blocked = await runEngine(release, { cwd });
    assert.equal(blocked.exitCode, 10);
    assert.equal(blocked.blocked, 'manual_gate');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('reopen build_package bumps prerelease n', async () => {
  const { getPreset } = await import('../scripts/release-runner/presets/index.mjs');
  const steps = getPreset('plugin-free-stable');
  const release = createReleaseRecord('4.0.0', 'plugin-free-stable', 'standard', steps, {
    channel: 'beta',
  });
  release.steps.build_package = { status: 'done', at: new Date().toISOString() };
  cascadeReopen(release, 'build_package', 'plugin-free-stable');
  assert.equal(release.prerelease.n, 2);
  assert.equal(release.steps.build_package.status, 'pending');
});

test('run --confirm passes confirm gate', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    let release = createReleaseRecord('1.0.0', 'fixture', 'standard', fixturePreset);
    release.edition = 'fixture';
    release.steps.auto_ok = { status: 'done', at: new Date().toISOString() };
    release.steps.manual_gate = { status: 'done', at: new Date().toISOString() };
    saveRelease(release, cwd);

    const result = await runEngine(release, { cwd, confirm: 'confirm_gate' });
    assert.equal(result.exitCode, 0);
    assert.equal(result.release.steps.confirm_gate.status, 'done');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('status payload marks the current manual gate as waiting', async () => {
  const { buildStatusPayload } = await import('../scripts/release-runner/engine/engine.mjs');
  const release = createReleaseRecord('1.0.0', 'fixture', 'standard', fixturePreset);
  release.edition = 'fixture';
  release.steps.auto_ok = { status: 'done', at: new Date().toISOString() };
  const steps = buildStatusPayload(release, 'fixture').steps;
  assert.equal(steps.find((s) => s.id === 'manual_gate').status, 'waiting');
  assert.equal(steps.find((s) => s.id === 'confirm_gate').status, 'pending');
  assert.equal(release.steps.manual_gate.status, 'pending', 'waiting is never persisted');
});

test('status payload reports running while an auto step executes', async () => {
  const { buildStatusPayload, getActiveStepId } = await import('../scripts/release-runner/engine/engine.mjs');
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  const original = fixturePreset[0].run;
  let seen;
  try {
    const release = createReleaseRecord('1.0.0', 'fixture', 'standard', fixturePreset);
    release.edition = 'fixture';
    saveRelease(release, cwd);
    fixturePreset[0].run = async () => {
      seen = buildStatusPayload(release, 'fixture').steps.find((s) => s.id === 'auto_ok').status;
    };
    await runEngine(release, { cwd });
    assert.equal(seen, 'running');
    assert.equal(getActiveStepId(), null);
  } finally {
    fixturePreset[0].run = original;
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('status payload exposes type, publish flag and resolved command', async () => {
  const { buildStatusPayload } = await import('../scripts/release-runner/engine/engine.mjs');
  const { getPreset } = await import('../scripts/release-runner/presets/index.mjs');
  const release = createReleaseRecord('4.11.0', 'plugin-free-stable', 'standard', getPreset('plugin-free-stable'));
  const steps = buildStatusPayload(release, 'plugin-free-stable').steps;
  const gh = steps.find((s) => s.id === 'github_release');
  assert.equal(gh.type, 'confirm');
  assert.equal(gh.publish, true);
  assert.equal(gh.command, 'gh release create 4.11.0 --target master --generate-notes');
  assert.equal(steps.find((s) => s.id === 'merge_hotfixes').publish, false);
});

test('getPreset resolves legacy free and pro ids', async () => {
  const { getPreset } = await import('../scripts/release-runner/presets/index.mjs');
  assert.equal(getPreset('plugin-free-stable'), getPreset('plugin-free-stable'));
  assert.equal(getPreset('pro'), getPreset('plugin-pro-stable'));
});
