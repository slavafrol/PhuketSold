import assert from 'node:assert/strict';
import test from 'node:test';
import { redactSecrets } from './redact-secrets.mjs';

test('redacts known values literally, including overlapping values, without changing the caller list', () => {
  const password = 'synthetic.*$&[value]';
  const connection = `Host=127.0.0.1;Password=${password};Database=example`;
  const secrets = [password, connection, ''];
  assert.equal(redactSecrets(`Failed for ${connection}\nReceived ${password}`, secrets),
    'Failed for [secret redacted]\nReceived [secret redacted]');
  assert.deepEqual(secrets, [password, connection, '']);
});

test('masks common database URLs, JWTs, Supabase keys and generated passwords', () => {
  const samples = [
    ['postgres://example:synthetic@localhost/example', '[database URL redacted]'],
    ['postgresql://example:synthetic@localhost/example', '[database URL redacted]'],
    ['eyJsynthetic.payload.signature', '[token redacted]'],
    ['sb_secret_synthetic_example', '[key redacted]'],
    ['sb_publishable_synthetic_example', '[key redacted]'],
    ['abcdef01'.repeat(8), '[secret redacted]'],
  ];
  for (const [value, expected] of samples) {
    assert.equal(redactSecrets(`Failed for ${value}`), `Failed for ${expected}`);
  }
});

test('removes credential-labelled lines while preserving useful diagnostics', () => {
  const output = [
    'Database command failed (1)',
    'PASSWORD: synthetic',
    'API_KEY: synthetic',
    'access-token: synthetic',
    'service_role_key: synthetic',
    'secret key: synthetic',
    'Expected HTTP 200; got HTTP 503',
  ].join('\n');
  assert.equal(redactSecrets(output), 'Database command failed (1)\nExpected HTTP 200; got HTTP 503');
  assert.equal(redactSecrets(), '');
});
