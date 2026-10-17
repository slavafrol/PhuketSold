# Inventory database foundation

The inventory foundation migration is [`20261014015637_initial_inventory.sql`](migrations/20261014015637_initial_inventory.sql). It creates eight tables in the private `marketplace` schema; all canonical schema changes live in `migrations/`:

| Table | Purpose |
| --- | --- |
| `profiles` | Stable Auth UUID, display name, EN/TH/RU preference; no phone/provider data |
| `categories`, `areas`, `developments` | Curated localized reference data; development-to-area consistency |
| `listing_groups` | Same-owner/type Sell collections or Buy wanted lists |
| `listings` | Incomplete drafts, whole-THB prices/targets, lifecycle, stable IDs/slugs, expiry and concurrency version |
| `listing_images` | Twelve reorderable slots, one optional cover, optimized variant paths and processing status |
| `listing_events` | Transactional append-only status/version history |

The `.NET` API maps all eight tables using EF Core/Npgsql 10 for runtime access, with no EF migrations or automatic schema creation. Its first public endpoint is the read-only reference catalog described below. Offers, chat, saved searches, referrals, contact consent and moderation reports require later migrations. No Storage bucket/policy or Auth provider configuration is created here.

## Local catalog

[`seed.sql`](seed.sql) contains three demo categories, two fictional areas and a fictional condominium, all labeled in EN/TH/RU. It is idempotent by fixture UUID and includes no users or listings. Seed loading is configured for local development; **do not use `--include-seed` against a hosted project**. Production catalogs need separate review/curation.

[`20261017063443_development_kind_default.sql`](migrations/20261017063443_development_kind_default.sql) sets the default for `developments.kind` to `development`, matching the .NET entity and EF runtime mapping. Omitting the column uses the default; explicit `village`, `condominium` or `development` values are preserved. Explicit NULL/invalid values still fail the existing constraints. This changes only column metadata, with no row rewrite or backfill. Omitted/explicit values were smoke-checked locally; there is no dedicated permanent suite for this low-impact default. Hosted application requires separate approval; a corrective migration can drop the default without changing stored classifications.

## Local verification

Use **OrbStack on macOS**, as recommended in [Supabase's local development guide](https://supabase.com/docs/guides/local-development/cli/getting-started). Install it once, open it, and leave it running while developing:

```bash
brew install --cask orbstack
```

The Supabase CLI is already a root dev dependency (`npm ci` after a fresh checkout). Run the standard local database checks from the repository root:

```bash
npm run db:check
```

[`scripts/check-database.mjs`](scripts/check-database.mjs) starts/reuses the local Supabase stack, checks **actual PostgreSQL 17.11**, applies pending local migrations, lints `marketplace` with a nonzero exit on SQL errors, loads the sample catalog, and executes the inventory integrity and catalog-reader verification scripts. It uses `psql` inside the database container; a separate host PostgreSQL/psql installation is optional. The first start downloads images; subsequent checks reuse the local services and cached images. CLI startup output is captured to keep local keys/credentials out of test logs.

For query/filter/index changes or a concrete performance concern, run `npm run db:check:plans`. This adds the 10,000-listing query-plan script and prints its plans for inspection. Synthetic query-plan fixtures are excluded from ordinary `db:check`; they are not required for every metadata/default change. Follow [the root verification guidance](../AGENTS.md#verification-scope) when deciding whether new permanent coverage is needed.

`db.major_version = 17` matches the hosted major version. The CLI's current linked image metadata is `17.11.0.003`; the runner also checks the running server's patch version instead of assuming any 17.x image is sufficient. If it differs from 17.11, the checks stop with an alignment error. Updating the expected version requires a deliberate review when the hosted project upgrades.

This command accepts no connection/target arguments and refuses remote Docker endpoints. It operates on the local `supabase_db_phuketsold` container, never runs `db push` or `db reset`, and keeps services running for development. Verification rolls its fixtures and temporary grants back. A failed SQL script closes its transaction when its client disconnects. No reset is needed; any `supabase db reset` requires explicit approval because it deletes database contents. Synthetic verification fixtures must never run against hosted/shared databases.

The constraints script verifies publishing requirements, 30-day expiry, Buy/Sell grouping and ownership, development consistency, nonnegative money, immutable identity/URLs, optimistic concurrency, audit history, image limits/reordering and browser access denial. It temporarily grants browser table privileges inside its rollback transaction to test RLS independently of the ordinary privilege barrier. The inventory constraints and optional query-plan scripts temporarily allow the restricted Supabase administrator to switch into `phuketsold_api`; the catalog-reader script temporarily grants access to its narrower reader group. These role grants also roll back. The optional query-plan script generates 10,000 synthetic listings and inspects newest/price/keyset/text plans, including Thai/Russian substring matching. It cleans the GIN pending list after the artificial bulk load; timings on synthetic inventory are not production budgets.

Validation on 2026-10-14: OrbStack was installed and started, and **`npm run db:check` passed against the actual local Supabase/PostgreSQL 17.11 stack**. This verified local migration application, `marketplace` SQL lint, the sample catalog, all constraint/RLS/concurrency/history checks, and 10,000-row query plans with Thai/Russian matching. Newest/price/keyset queries used their B-tree indexes, and the selective substring query used the trigram GIN index. The scripts used Supabase's real database roles/Auth schema, with synthetic user fixtures and rollback-only role grants. Node syntax and `git diff --check` also passed. Local services remain running and the hosted project is unchanged; SMS/LINE Login and Storage upload integrations have not been exercised.

Earlier PGlite/PostgreSQL 18.6 checks used minimal Auth/role stubs; they are superseded for schema compatibility by the actual 17.11 run. No PGlite dependency was added to the repository. OrbStack is workstation tooling, and the runner uses only Node's standard library and the existing CLI.

## Rollout and runtime setup

### Local API connection and catalog reader

After `npm run db:check`, run `npm run api:db:setup` from the repository root. OrbStack/Supabase must already be running. The command refuses target arguments and remote Docker endpoints, checks PostgreSQL **17.11** and the local container's port `54322`, applies pending migrations with `migration up --local`, then creates/reuses the `phuketsold_catalog_local` login. It never uses the hosted link, resets the database or rotates an existing password.

[`20261016090000_catalog_reader.sql`](migrations/20261016090000_catalog_reader.sql) adds a NOLOGIN/NOBYPASSRLS privilege group, `phuketsold_catalog_reader`. It grants schema usage and SELECT on only categories, areas and developments, with SELECT-only RLS policies for active rows; a development also requires an active parent area. No inventory/profile/history read or application write access is granted, and browser roles retain no schema/table access. The local login inherits only this group, has no admin/create/replication/bypass privileges, and uses a 20-connection limit plus a five-second statement timeout. Its read-only transaction default is additional protection; ordinary ACLs deny writes even if that default is disabled.

The generated connection is stored in `~/.microsoft/usersecrets/phuketsold-api-local/secrets.json` as `ConnectionStrings:Marketplace`, with mode `0600`. Passwords travel through subprocess stdin, not command arguments or logs. This development store is outside Git and unencrypted; use managed secret storage for any future deployment. The API also accepts the environment variable `ConnectionStrings__Marketplace`; [the placeholder example](../backend/.env.example) documents its format. Existing secrets are preserved. If the local role exists but its secret is missing or no longer matches, setup stops or the readiness check fails: explicit local credential recovery/rotation is required, rather than silently changing an existing password. After an approved database reset, rerun setup to recreate the role using the retained local secret.

`dotnet run --project backend/PhuketSold.Api` loads user-secrets through its Development launch profile. `/health` is database-independent. `/health/ready` executes a bounded SELECT referencing all three catalog tables using the runtime login, including when no active rows exist; unavailable connections, missing tables or denied permissions produce HTTP 503 without provider diagnostics. It is a dependency probe for the implemented catalog slice, not a whole-inventory schema/version validator. `GET /api/catalog` returns projected IDs/slugs/localized names (plus area/kind for developments), active records only, with stable ordering and a 60-second public cache lifetime. Database failures use safe Problem Details and `no-store`.

Run `dotnet build backend/PhuketSold.Api.Tests`, then `npm run api:check`. The runner verifies catalog RLS, inactive-parent filtering, an empty catalog and denied private reads/writes with rollback-only synthetic fixtures. It then runs the real API host tests for anonymous multilingual catalog reads, ordering, readiness/liveness, missing/unreachable database errors, the actual login's permissions, and all eight EF mappings against PostgreSQL column types/nullability. It accepts only the generated local reader connection and never forwards hosted credentials. No Auth user, listing or hosted fixture is created by this API check.

Validation on 2026-10-16: local PostgreSQL 17.11, `db:check`, all six API tests and a warning-free build passed. A live Kestrel smoke test using Development user-secrets returned HTTP 200 for readiness and a 1,409-byte catalog containing three categories, two areas and one development. Setup was rerun successfully without credential rotation, and the secret file's mode was verified as `0600`. The temporary API process was stopped after verification; local Supabase remains running. Hosted resources were unchanged.

This migration is additive, with no backfill. For shared rollout, review the new role/policies and provision the corresponding runtime login through an approved secret workflow; do not deploy the workstation login/password. Hosted application remains a separately approved operation. Roll back deployed changes through a forward corrective migration after assessing dependent logins; do not drop roles/tables automatically.

### Inventory foundation and future mutations

This is an additive first migration with no existing application data to backfill. Inspect the target and existing extensions/roles before applying it: it expects a fresh `marketplace` schema, no existing `phuketsold_api` role, Supabase's `auth.users` and `anon`/`authenticated` roles, and `pg_trgm` in the standard `extensions` schema. An existing `pg_trgm` installation in another schema must be reconciled in a reviewed migration first.

Before shared deployment, run full local verification, review the migration, confirm the intended linked project, and obtain explicit approval for `supabase db push`. No remote push, database reset, credential change, or hosted seed was performed while generating this migration. Supabase's [migration workflow](https://supabase.com/docs/guides/deployment/database-migrations) is the deployment reference.

When authenticated inventory mutations are implemented, provision a dedicated backend database login through an approved secret-management workflow and grant it the `phuketsold_api` privilege group, with explicit authorization tests. The current catalog login intentionally does **not** inherit that wider group. Neither group can log in or bypass RLS. Never grant either to `anon`, `authenticated` or `authenticator`; never use a table-owning/admin role for ordinary API requests. Browser access stays behind .NET, with no Data API exposure of `marketplace`. Backend authorization and narrow public projections are required because the inventory group's RLS policy intentionally allows server access to all rows. Phone OTP/LINE verification, active catalog checks, rate limits and legal state transitions remain API responsibilities.

Wrap mutations in a transaction and use the authenticated UUID as a transaction-local audit actor:

```sql
select set_config('app.actor_id', @validated_user_uuid, true);
update marketplace.listings
set price_thb = @price
where id = @listing_id and owner_id = @validated_user_uuid and version = @expected_version;
-- Zero affected rows means missing/unauthorized/stale; resolve without leaking ownership.
```

First publication defaults to thirty days; an earlier explicit expiry is accepted. An expiry worker and renewal endpoints are follow-on implementation: the schema does not schedule jobs. Public active browse must filter by status, hidden flag and future expiry. Historical URLs preserve sold/expired inventory through a deliberate public projection. Do not expose full rows, draft groups, owner archives or audit records.

No bucket has been made public and no browser upload capability has been enabled. Before upload functionality, add a reviewed Storage migration/authorization path and validate actual image bytes/EXIF, ownership, sizes and derivatives. Metadata constraints alone do not validate uploaded content.

Rollback: the migration is transactional on initial application, so a failure rolls back its DDL. After successful deployment, use a forward corrective migration; do not delete this migration or drop populated tables/roles. Destructive removal requires explicit approval, a backup and retention review. Auth-account deletion is restricted to preserve inventory history until an anonymization/erasure workflow is designed.
