// Known values cover formats that generic CLI credential patterns cannot infer.
export function redactSecrets(text = '', knownSecrets = []) {
  let output = text;
  const secrets = knownSecrets.filter(secret => typeof secret === 'string' && secret.length > 0)
    .sort((left, right) => right.length - left.length);
  for (const secret of secrets) output = output.replaceAll(secret, '[secret redacted]');

  return output
    .replace(/postgres(?:ql)?:\/\/[^\s'"<>]+/gi, '[database URL redacted]')
    .replace(/\beyJ[\w-]+\.[\w-]+\.[\w-]+\b/g, '[token redacted]')
    .replace(/\bsb_(?:secret|publishable)_[\w-]+\b/g, '[key redacted]')
    .replace(/[a-f0-9]{64}/gi, '[secret redacted]')
    .split('\n')
    .filter(line => !/password|api.?key|access.?token|service.?role.?key|secret.?key/i.test(line))
    .join('\n');
}
