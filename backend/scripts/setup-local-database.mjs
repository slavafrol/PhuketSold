import { randomBytes } from 'node:crypto';
import { chmod } from 'node:fs/promises';
import { resolve } from 'node:path';
import { root, apiProject, secretsFile, login, psqlArgs, run, checkLocalDatabase, readSecrets, localConnection } from './local-database.mjs';

async function main() {
  await checkLocalDatabase();
  const secrets = await readSecrets();
  const existing = (await run('docker', [...psqlArgs, '-Atc', `select count(*) from pg_roles where rolname = '${login}';`])).trim() === '1';
  let connection;
  let password;
  if (secrets['ConnectionStrings:Marketplace']) {
    connection = localConnection(secrets);
    password = connection.match(/Password=([a-f0-9]{64});/)[1];
  } else {
    if (existing) throw new Error('Local login already exists but its secret is missing. Explicit credential recovery is required; no rotation was performed.');
    password = randomBytes(32).toString('hex');
    connection = `Host=127.0.0.1;Port=54322;Database=postgres;Username=${login};Password=${password};Timeout=5;Maximum Pool Size=20;Application Name=PhuketSold.Api`;
  }

  // Local pending SQL only; no reset, remote push, hosted seed or linked target.
  await run(process.execPath, [resolve(root, 'node_modules/supabase/dist/supabase.js'), 'migration', 'up', '--local']);
  if (!existing) {
    // Persist before provisioning so an interrupted setup can safely reuse it.
    await run('dotnet', ['user-secrets', 'set', '--project', apiProject], JSON.stringify({ 'ConnectionStrings:Marketplace': connection }));
    await chmod(secretsFile, 0o600);
  }
  await run('docker', psqlArgs, `
    begin;
    ${!existing ? `create role ${login} login password '${password}' inherit nosuperuser nocreatedb nocreaterole noreplication nobypassrls connection limit 20;` : ''}
    do $$ begin
      if exists (select 1 from pg_roles where rolname = '${login}' and
          (rolsuper or rolbypassrls or rolcreatedb or rolcreaterole or rolreplication or not rolcanlogin))
        or exists (select 1 from pg_auth_members m join pg_roles member on member.oid = m.member
          join pg_roles granted on granted.oid = m.roleid
          where member.rolname = '${login}' and granted.rolname <> 'phuketsold_catalog_reader') then
        raise exception 'Unexpected local runtime role privileges';
      end if;
    end $$;
    grant phuketsold_catalog_reader to ${login};
    grant connect on database postgres to ${login};
    alter role ${login} set default_transaction_read_only = on;
    alter role ${login} set statement_timeout = '5s';
    alter role ${login} set search_path = '';
    commit;
  `);
  console.log('Local catalog login provisioned/reused; connection stored in .NET user-secrets outside Git.');
  console.log('Only active catalog SELECT is granted. No hosted resources or existing passwords were changed.');
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
