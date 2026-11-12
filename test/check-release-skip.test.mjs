import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const projectDirectory = fileURLToPath(new URL('..', import.meta.url));
const script = 'scripts/check-release.sh';

test('explicit CI skip exits before validating a nonexistent project', () => {
  const result = spawnSync('bash', [script, '/nonexistent-plugin'], {
    cwd: projectDirectory,
    env: { ...process.env, PP_SKIP_RELEASE_CHECK: '1' }, encoding: 'utf8',
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Skipping release checks/);
});

test('normal release check still rejects a nonexistent project', () => {
  const result = spawnSync('bash', [script, '/nonexistent-plugin'], {
    cwd: projectDirectory,
    env: { ...process.env, PP_SKIP_RELEASE_CHECK: '0' }, encoding: 'utf8',
  });
  assert.ifError(result.error);
  assert.notEqual(result.status, 0);
});
