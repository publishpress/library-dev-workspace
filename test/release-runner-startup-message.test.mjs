import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatStartupMessage } from '../scripts/release-runner/server/http.mjs';

test('startup message tells the dev to open the URL', () => {
  const text = formatStartupMessage({
    host: '127.0.0.1',
    port: 9876,
    cwd: '/plugin',
  });
  assert.match(text, /Open this URL in your browser:/);
  assert.match(text, /http:\/\/127\.0\.0\.1:9876\//);
  assert.match(text, /Leave this terminal running/);
  assert.match(text, /Working directory: \/plugin/);
  assert.doesNotMatch(text, /\u001b\]8;;/);
});

test('startup message wraps the URL as a terminal hyperlink when asked', () => {
  const text = formatStartupMessage({
    host: '127.0.0.1',
    port: 9876,
    cwd: '/plugin',
    hyperlink: true,
  });
  assert.match(text, /\u001b\]8;;http:\/\/127\.0\.0\.1:9876\/\u001b\\/);
});
