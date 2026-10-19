import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { resolvePipeline } from '../scripts/release-runner/presets/index.mjs';
import { readTestSuites } from '../scripts/release-runner/steps/testing.mjs';

test('missing extra.test-suites keeps one manual testing step', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-test-'));
  try {
    writeFileSync(join(cwd, 'composer.json'), JSON.stringify({ name: 'acme/plugin' }));
    const ids = resolvePipeline('plugin-free-stable', cwd).map((step) => step.id);
    assert.equal(ids.filter((id) => id === 'testing').length, 1);
    assert.ok(!ids.includes('test_unit'));
    assert.ok(!ids.includes('test_integration'));
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test('extra.test-suites expands to composer test:<suite> steps', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rr-test-'));
  try {
    writeFileSync(join(cwd, 'composer.json'), JSON.stringify({
      extra: { 'test-suites': ['unit', 'integration'] },
    }));
    assert.deepEqual(readTestSuites(cwd), ['unit', 'integration']);
    const steps = resolvePipeline('plugin-pro-stable', cwd);
    const unit = steps.find((step) => step.id === 'test_unit');
    const integration = steps.find((step) => step.id === 'test_integration');
    assert.equal(unit?.type, 'auto');
    assert.equal(unit?.command, 'composer test:unit');
    assert.equal(integration?.command, 'composer test:integration');
    assert.ok(!steps.some((step) => step.id === 'testing'));
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});
