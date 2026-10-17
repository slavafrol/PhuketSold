import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { redactSecrets } from '../../scripts/redact-secrets.mjs';
import { root, psqlArgs, run, checkLocalDatabase, readSecrets, localConnection } from './local-database.mjs';

async function main() {
  await checkLocalDatabase();
  const connection = localConnection(await readSecrets());
  await run('docker', psqlArgs, await readFile(resolve(root, 'supabase/verification/catalog_reader.sql'), 'utf8'));
  console.log('PASS: catalog RLS, parent visibility, empty state and denied private data/writes (rollback-only fixtures).');
  // Sanitize test diagnostics too; provisioning stdout/stderr stays suppressed.
  try {
    const output = await run('dotnet', ['test', 'backend/PhuketSold.Api.Tests', '--no-restore'], undefined,
      { ...process.env, PHUKETSOLD_TEST_CONNECTION: connection });
    console.log(redactSecrets(output, [connection]).trim());
  } catch (error) {
    // SQL/provisioning stderr stays suppressed; these are test diagnostics only.
    if (error.stdout) console.error(redactSecrets(error.stdout, [connection]));
    throw error;
  }
}

main().catch(error => { console.error(redactSecrets(error.message)); process.exitCode = 1; });
