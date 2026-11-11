import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const bash = process.platform === 'win32' ? 'C:/laragon/bin/git/bin/bash.exe' : 'bash';
const script = fileURLToPath(new URL('../scripts/check-release.sh', import.meta.url));

test('explicit CI skip exits before validating a nonexistent project', () => {
  const result = spawnSync(bash, [script, '/nonexistent-plugin'], {
    env: { ...process.env, PP_SKIP_RELEASE_CHECK: '1' }, encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Skipping release checks/);
});

test('normal release check still rejects a nonexistent project', () => {
  const result = spawnSync(bash, [script, '/nonexistent-plugin'], {
    env: { ...process.env, PP_SKIP_RELEASE_CHECK: '0' }, encoding: 'utf8',
  });
  assert.notEqual(result.status, 0);
});
