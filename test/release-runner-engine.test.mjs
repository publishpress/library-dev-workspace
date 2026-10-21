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
    release.steps.auto_next = { status: 'done', at: new Date().toISOString() };
    release.steps.manual_gate = { status: 'done', at: new Date().toISOString() };
    saveRelease(release, cwd);

    const result = await runEngine(release, { cwd, confirm: 'confirm_gate' });
    assert.equal(result.exitCode, 10);
    assert.equal(result.blocked, 'localize_auto');
    assert.equal(result.release.steps.confirm_gate.status, 'done');
    assert.equal(result.release.steps.auto_final.status, 'done');
    assert.equal(result.release.steps.localize_auto.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('status payload marks the current manual gate as waiting', async () => {
  const { buildStatusPayload } = await import('../scripts/release-runner/engine/engine.mjs');
  const release = createReleaseRecord('1.0.0', 'fixture', 'standard', fixturePreset);
  release.edition = 'fixture';
  release.steps.auto_ok = { status: 'done', at: new Date().toISOString() };
  release.steps.auto_next = { status: 'done', at: new Date().toISOString() };
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

test('auto-run beat keeps the finished step current before the next starts', async () => {
  const { getCurrentStepId } = await import('../scripts/release-runner/engine/engine.mjs');
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    const release = createReleaseRecord('1.0.0', 'fixture', 'standard', fixturePreset);
    release.edition = 'fixture';
    saveRelease(release, cwd);
    let sawFinishedCurrent = false;
    const pending = runEngine(release, { cwd, beatMs: 400 });
    const start = Date.now();
    while (Date.now() - start < 1500) {
      let loaded;
      try {
        loaded = loadCurrentRelease(cwd);
      } catch {
        loaded = null;
      }
      if (loaded?.steps.auto_ok.status === 'done' && getCurrentStepId(loaded, 'fixture') === 'auto_ok') {
        sawFinishedCurrent = true;
        break;
      }
      await new Promise((resolve) => {
        setTimeout(resolve, 20);
      });
    }
    const result = await pending;
    assert.equal(sawFinishedCurrent, true);
    assert.equal(result.exitCode, 10);
    assert.equal(result.blocked, 'manual_gate');
    assert.equal(getCurrentStepId(loadCurrentRelease(cwd), 'fixture'), 'manual_gate');
  } finally {
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

function releaseAt(cwd, doneIds = []) {
  const release = createReleaseRecord('1.0.0', 'fixture', 'standard', fixturePreset);
  release.edition = 'fixture';
  const at = new Date().toISOString();
  for (const id of doneIds) {
    release.steps[id] = { status: 'done', at };
  }
  saveRelease(release, cwd);
  return release;
}

test('skip marks the current auto step and does not run the next', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    releaseAt(cwd);
    const code = await commands.skip(['auto_ok'], cwd, { json: false, yes: false, autoRun: false });
    const loaded = loadCurrentRelease(cwd);
    assert.equal(code, 0);
    assert.equal(loaded.steps.auto_ok.status, 'skipped');
    assert.equal(loaded.steps.auto_next.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('skip is rejected when auto-run is on, for a later step, and for confirm', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    releaseAt(cwd);
    const flags = { json: false, yes: false, autoRun: false };
    await assert.rejects(
      () => commands.skip(['auto_ok'], cwd, { ...flags, autoRun: true }),
      /auto-run is off/
    );
    await assert.rejects(() => commands.skip(['auto_next'], cwd, flags), /current step/);
    await assert.rejects(() => commands.skip(['github_auth'], cwd, flags), /github_auth cannot be skipped/);
    releaseAt(cwd, ['auto_ok', 'auto_next', 'manual_gate']);
    await assert.rejects(() => commands.skip(['confirm_gate'], cwd, flags), /cannot be skipped/);
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('rerun with auto-run off executes only that auto step', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    releaseAt(cwd, ['auto_ok', 'auto_next']);
    const code = await commands.rerun(['auto_ok'], cwd, { json: false, yes: false, autoRun: false });
    const loaded = loadCurrentRelease(cwd);
    assert.equal(code, 0);
    assert.equal(loaded.steps.auto_ok.status, 'done');
    assert.equal(loaded.steps.auto_next.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('rerun with auto-run on continues until the next gate', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    releaseAt(cwd, ['auto_ok', 'auto_next', 'manual_gate']);
    const code = await commands.rerun(['auto_ok'], cwd, { json: false, yes: false, autoRun: true });
    const loaded = loadCurrentRelease(cwd);
    assert.equal(code, 10);
    assert.equal(loaded.steps.auto_ok.status, 'done');
    assert.equal(loaded.steps.auto_next.status, 'done');
    assert.equal(loaded.steps.manual_gate.status, 'pending');
    assert.equal(loaded.steps.confirm_gate.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('rerun of a manual step cascades without completing it', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    releaseAt(cwd, ['auto_ok', 'auto_next', 'manual_gate', 'confirm_gate']);
    const code = await commands.rerun(['manual_gate'], cwd, { json: false, yes: false, autoRun: true });
    const loaded = loadCurrentRelease(cwd);
    assert.equal(code, 0);
    assert.equal(loaded.steps.auto_ok.status, 'done');
    assert.equal(loaded.steps.manual_gate.status, 'pending');
    assert.equal(loaded.steps.confirm_gate.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('reopen cascades without executing the auto step', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    releaseAt(cwd, ['auto_ok', 'auto_next']);
    const code = await commands.reopen(['auto_ok'], cwd, { json: false, yes: false, autoRun: true });
    const loaded = loadCurrentRelease(cwd);
    assert.equal(code, 0);
    assert.equal(loaded.steps.auto_ok.status, 'pending');
    assert.equal(loaded.steps.auto_next.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('auto-run stops before Localization without running it', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    releaseAt(cwd, ['auto_ok', 'auto_next', 'manual_gate', 'confirm_gate', 'auto_final']);
    const result = await runEngine(loadCurrentRelease(cwd), { cwd });
    assert.equal(result.exitCode, 10);
    assert.equal(result.blocked, 'localize_auto');
    assert.equal(result.release.steps.localize_auto.status, 'pending');
    assert.equal(result.release.steps.after_localize.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('run enters Localization when that step is already current', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    releaseAt(cwd, ['auto_ok', 'auto_next', 'manual_gate', 'confirm_gate', 'auto_final']);
    const code = await commands.run([], cwd, { json: false, yes: false, autoRun: true });
    const loaded = loadCurrentRelease(cwd);
    assert.equal(code, 10);
    assert.equal(loaded.steps.localize_auto.status, 'done');
    assert.equal(loaded.steps.localize_confirm.status, 'pending');
    assert.equal(loaded.steps.after_localize.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('skip Localization with auto-run on skips the phase and continues', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    releaseAt(cwd, ['auto_ok', 'auto_next', 'manual_gate', 'confirm_gate', 'auto_final']);
    const code = await commands.skip(['localize_auto'], cwd, { json: false, yes: false, autoRun: true });
    const loaded = loadCurrentRelease(cwd);
    assert.equal(code, 0);
    assert.equal(loaded.steps.localize_auto.status, 'skipped');
    assert.equal(loaded.steps.localize_confirm.status, 'skipped');
    assert.equal(loaded.steps.after_localize.status, 'done');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('skip Localization with auto-run off skips the phase and stops', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-engine-'));
  try {
    releaseAt(cwd, ['auto_ok', 'auto_next', 'manual_gate', 'confirm_gate', 'auto_final']);
    const code = await commands.skip(['localize_auto'], cwd, { json: false, yes: false, autoRun: false });
    const loaded = loadCurrentRelease(cwd);
    assert.equal(code, 0);
    assert.equal(loaded.steps.localize_auto.status, 'skipped');
    assert.equal(loaded.steps.localize_confirm.status, 'skipped');
    assert.equal(loaded.steps.after_localize.status, 'pending');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('getPreset resolves legacy free and pro ids', async () => {
  const { getPreset } = await import('../scripts/release-runner/presets/index.mjs');
  assert.equal(getPreset('plugin-free-stable'), getPreset('plugin-free-stable'));
  assert.equal(getPreset('pro'), getPreset('plugin-pro-stable'));
});
