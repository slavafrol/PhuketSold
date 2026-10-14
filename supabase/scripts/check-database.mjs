import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const root = fileURLToPath(new URL('../../', import.meta.url));
const cli = resolve(root, 'node_modules/supabase/dist/supabase.js');
const expectedVersion = '17.11';

function redact(text) {
  return text
    .replace(/postgres(?:ql)?:\/\/[^\s'"<>]+/gi, '[database URL redacted]')
    .replace(/\beyJ[\w-]+\.[\w-]+\.[\w-]+\b/g, '[token redacted]')
    .replace(/\bsb_(?:secret|publishable)_[\w-]+\b/g, '[key redacted]')
    .split('\n')
    .filter(line => !/password|api.?key|access.?token|service.?role.?key|secret.?key/i.test(line))
    .join('\n');
}

function run(command, args, input) {
  return new Promise((accept, reject) => {
    const child = spawn(command, args, { cwd: root, stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    child.stdout.setEncoding('utf8').on('data', chunk => { stdout = (stdout + chunk).slice(-262144); });
    child.stderr.setEncoding('utf8').on('data', chunk => { stderr = (stderr + chunk).slice(-262144); });
    child.once('error', error => reject(new Error(`${command}: ${error.code === 'ENOENT' ? 'not installed/on PATH' : error.message}`)));
    child.stdin.on('error', error => { if (error.code !== 'EPIPE') reject(error); });
    child.once('close', code => {
      if (code === 0) accept(stdout);
      else reject(new Error(`${command} ${args.join(' ')} failed (${code}).\n${redact(stderr).slice(-6000)}`));
    });
    child.stdin.end(input);
  });
}

async function supabase(args) {
  // Capture CLI output: start/status may include local credentials.
  return run(process.execPath, [cli, ...args]);
}

async function main() {
  if (process.argv.length > 2) throw new Error('db:check accepts no target or connection arguments; it only tests the local project.');
  const config = await readFile(resolve(root, 'supabase/config.toml'), 'utf8');
  const project = config.match(/^project_id\s*=\s*"([a-zA-Z0-9_-]+)"/m)?.[1];
  if (!project) throw new Error('Expected a simple project_id in supabase/config.toml.');
  const container = `supabase_db_${project}`;

  console.log('Checking the local container runtime (open OrbStack first)...');
  // Docker contexts can point at remote engines. Explicitly refuse that before
  // starting services or writing fixtures, even if Docker itself is reachable.
  const context = process.env.DOCKER_CONTEXT;
  const endpoint = !context && process.env.DOCKER_HOST
    ? process.env.DOCKER_HOST
    : (await run('docker', ['context', 'inspect', ...(context ? [context] : []), '--format', '{{.Endpoints.docker.Host}}'])).trim();
  if (!endpoint.startsWith('unix://')) throw new Error('db:check requires a local Docker Unix socket; remote container engines are refused.');
  await run('docker', ['info', '--format', '{{.ServerVersion}}']);

  console.log('Starting/reusing local Supabase; the first run downloads service images...');
  await supabase(['start']);

  const psqlArgs = ['exec', '-i', container, 'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'];
  const version = (await run('docker', [...psqlArgs, '-Atc', 'show server_version;'])).trim();
  if (version.split(' ')[0] !== expectedVersion) {
    throw new Error(`Expected PostgreSQL ${expectedVersion}, got ${version}. Align the local Supabase database image before running verification.`);
  }
  console.log(`PASS: actual PostgreSQL ${version}`);

  await supabase(['migration', 'up', '--local']);
  console.log('PASS: local migrations');

  await supabase(['db', 'lint', '--local', '--schema', 'marketplace', '--fail-on', 'error']);
  console.log('PASS: marketplace SQL lint');

  for (const [file, label] of [
    ['supabase/seed.sql', 'local demo catalog'],
    ['supabase/verification/initial_inventory.sql', 'constraints, RLS, concurrency and lifecycle history'],
    ['supabase/verification/inventory_query_plans.sql', '10,000-listing query plans and multilingual search'],
  ]) {
    const output = await run('docker', psqlArgs, await readFile(resolve(root, file), 'utf8'));
    if (file.includes('query_plans')) console.log(output.trim());
    console.log(`PASS: ${label}`);
  }
  console.log('Database checks passed. Local services remain running for development.');
}

main().catch(error => {
  console.error(redact(error.message));
  process.exitCode = 1;
});
