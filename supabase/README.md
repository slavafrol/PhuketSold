# Inventory database foundation

The canonical migration is [`20261014015637_initial_inventory.sql`](migrations/20261014015637_initial_inventory.sql). It creates eight tables in the private `marketplace` schema:

| Table | Purpose |
| --- | --- |
| `profiles` | Stable Auth UUID, display name, EN/TH/RU preference; no phone/provider data |
| `categories`, `areas`, `developments` | Curated localized reference data; development-to-area consistency |
| `listing_groups` | Same-owner/type Sell collections or Buy wanted lists |
| `listings` | Incomplete drafts, whole-THB prices/targets, lifecycle, stable IDs/slugs, expiry and concurrency version |
| `listing_images` | Twelve reorderable slots, one optional cover, optimized variant paths and processing status |
| `listing_events` | Transactional append-only status/version history |

The `.NET` API is not wired to these tables yet. Offers, chat, saved searches, referrals, contact consent and moderation reports require later migrations. No Storage bucket/policy or Auth provider configuration is created here.

## Local catalog

[`seed.sql`](seed.sql) contains three demo categories, two fictional areas and a fictional condominium, all labeled in EN/TH/RU. It is idempotent by fixture UUID and includes no users or listings. Seed loading is configured for local development; **do not use `--include-seed` against a hosted project**. Production catalogs need separate review/curation.

## Local verification

Use **OrbStack on macOS**, as recommended in [Supabase's local development guide](https://supabase.com/docs/guides/local-development/cli/getting-started). Install it once, open it, and leave it running while developing:

```bash
brew install --cask orbstack
```

The Supabase CLI is already a root dev dependency (`npm ci` after a fresh checkout). Run the complete local database checks from the repository root:

```bash
npm run db:check
```

[`scripts/check-database.mjs`](scripts/check-database.mjs) starts/reuses the local Supabase stack, checks **actual PostgreSQL 17.11**, applies pending local migrations, lints `marketplace` with a nonzero exit on SQL errors, loads the sample catalog, and executes both verification scripts. It uses `psql` inside the database container; a separate host PostgreSQL/psql installation is optional. The first start downloads images; subsequent checks reuse the local services and cached images. CLI startup output is captured to keep local keys/credentials out of test logs. Query plans are printed for inspection.

`db.major_version = 17` matches the hosted major version. The CLI's current linked image metadata is `17.11.0.003`; the runner also checks the running server's patch version instead of assuming any 17.x image is sufficient. If it differs from 17.11, the checks stop with an alignment error. Updating the expected version requires a deliberate review when the hosted project upgrades.

This command accepts no connection/target arguments and refuses remote Docker endpoints. It operates on the local `supabase_db_phuketsold` container, never runs `db push` or `db reset`, and keeps services running for development. Verification rolls its fixtures and temporary grants back. A failed SQL script closes its transaction when its client disconnects. No reset is needed; any `supabase db reset` requires explicit approval because it deletes database contents. Synthetic verification fixtures must never run against hosted/shared databases.

The constraints script verifies publishing requirements, 30-day expiry, Buy/Sell grouping and ownership, development consistency, nonnegative money, immutable identity/URLs, optimistic concurrency, audit history, image limits/reordering and browser access denial. It temporarily grants browser table privileges inside its rollback transaction to test RLS independently of the ordinary privilege barrier. Both verification scripts temporarily allow the restricted Supabase administrator to switch into `phuketsold_api`; that role grant also rolls back. The query-plan script generates 10,000 synthetic listings and inspects newest/price/keyset/text plans, including Thai/Russian substring matching. It cleans the GIN pending list after the artificial bulk load; timings on synthetic inventory are not production budgets.

Validation on 2026-10-14: OrbStack was installed and started, and **`npm run db:check` passed against the actual local Supabase/PostgreSQL 17.11 stack**. This verified local migration application, `marketplace` SQL lint, the sample catalog, all constraint/RLS/concurrency/history checks, and 10,000-row query plans with Thai/Russian matching. Newest/price/keyset queries used their B-tree indexes, and the selective substring query used the trigram GIN index. The scripts used Supabase's real database roles/Auth schema, with synthetic user fixtures and rollback-only role grants. Node syntax and `git diff --check` also passed. Local services remain running and the hosted project is unchanged; SMS/LINE Login and Storage upload integrations have not been exercised.

Earlier PGlite/PostgreSQL 18.6 checks used minimal Auth/role stubs; they are superseded for schema compatibility by the actual 17.11 run. No PGlite dependency was added to the repository. OrbStack is workstation tooling, and the runner uses only Node's standard library and the existing CLI.

## Rollout and runtime setup

This is an additive first migration with no existing application data to backfill. Inspect the target and existing extensions/roles before applying it: it expects a fresh `marketplace` schema, no existing `phuketsold_api` role, Supabase's `auth.users` and `anon`/`authenticated` roles, and `pg_trgm` in the standard `extensions` schema. An existing `pg_trgm` installation in another schema must be reconciled in a reviewed migration first.

Before shared deployment, run full local verification, review the migration, confirm the intended linked project, and obtain explicit approval for `supabase db push`. No remote push, database reset, credential change, or hosted seed was performed while generating this migration. Supabase's [migration workflow](https://supabase.com/docs/guides/deployment/database-migrations) is the deployment reference.

Provision a dedicated backend database login through an approved secret-management workflow and grant it the `phuketsold_api` privilege group. The group itself cannot log in or bypass RLS. Never grant it to `anon`, `authenticated` or `authenticator`; never use a table-owning/admin role for ordinary API requests. Browser access stays behind .NET, with no Data API exposure of `marketplace`. Backend authorization and narrow public projections are required because its RLS policy intentionally allows server access to all rows. Phone OTP/LINE verification, active catalog checks, rate limits and legal state transitions remain API responsibilities.

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
