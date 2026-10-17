# PhuketSold

This repository contains an Angular application, an ASP.NET Core 10 API with a read-only catalog endpoint, Supabase configuration and migrations, and product and engineering documentation.

| Directory | Contents |
| --- | --- |
| `frontend/` | Angular application, including SSR configuration, source, public assets, and npm lockfile |
| `backend/PhuketSold.Api/` | ASP.NET Core 10 API host |
| `supabase/` | Schema migrations, local sample catalog, verification SQL and Supabase configuration |
| `docs/` | Product, architecture, and performance documents |

## Local development

Prerequisites: Node.js 24, npm 11, .NET SDK 10, and OrbStack on macOS. Run all commands below from the repository root. The Supabase CLI is a root npm dependency; no global CLI installation or new `supabase init` is needed.

### First-time setup

Install dependencies, start/verify local Supabase, and provision the API's restricted database login:

```bash
npm ci
npm --prefix frontend ci
dotnet restore backend/PhuketSold.Api.Tests
open -a OrbStack
npm run db:check
npm run api:db:setup
```

`db:check` starts/reuses the local Supabase stack, verifies actual PostgreSQL 17.11, applies pending local migrations, loads the demo catalog, and runs SQL lint and rollback-only integrity/RLS checks. It leaves Supabase running. The first startup can take longer while container images download.

`api:db:setup` applies pending **local** SQL migrations and creates/reuses `phuketsold_catalog_local`, which can only select active reference data. It generates a local password and writes `ConnectionStrings:Marketplace` to .NET user-secrets outside Git (file permission `0600`); no password appears in command arguments or output. Existing passwords are not rotated. User-secrets are a development plaintext store, not a production vault. See [backend/.env.example](backend/.env.example) for the configuration key and a placeholder connection; .NET does not automatically load `.env` files.

### Daily startup

Start OrbStack and Supabase, then apply any pending local migrations, including after pulling schema changes:

```bash
open -a OrbStack
npx supabase start
npx supabase migration up --local
```

Supabase runs in background containers. You do not need to repeat dependency installation, login provisioning or the full database checks on every startup.

Start the API in a terminal and leave it running:

```bash
dotnet run --project backend/PhuketSold.Api
```

Start Angular in another terminal and leave it running:

```bash
npm --prefix frontend start
```

| Service | Local address |
| --- | --- |
| Angular | <http://localhost:4200> |
| .NET API | <http://localhost:5000> |
| Supabase Studio | <http://localhost:54323> |
| PostgreSQL | `127.0.0.1:54322` |

The frontend currently shows the Angular starter page; it is not yet connected to the API. The API loads its local connection from user-secrets through the default Development launch profile.

### Inspecting and testing the API

| Route | Behavior |
| --- | --- |
| `GET /health` | Process liveness, independent of PostgreSQL |
| `GET /health/ready` | Database/schema/reader-permission readiness; safe Problem Details with HTTP 503 on failure |
| `GET /api/catalog` | Anonymous active categories, areas and developments, with EN/TH/RU names |

Open these endpoints in a browser, or run:

```bash
curl -i http://localhost:5000/health
curl -i http://localhost:5000/health/ready
curl -i http://localhost:5000/api/catalog
```

With local Supabase and the reader login available, all three should return HTTP 200. The demo catalog includes three categories, two areas and one development, unless you have modified the local data.

To inspect the current schema, open Supabase Studio, select **Table Editor**, switch the schema from `public` to **`marketplace`**, and open a table's **Definition** view. The SQL Editor can also inspect columns, defaults, constraints, indexes, triggers and policies. This shows the local database; the hosted dashboard reflects separately deployed changes.

### Database changes

Create a new SQL migration for each schema change; preserve already-applied migration files:

```bash
npx supabase migration new describe_your_change
```

Edit the new file in `supabase/migrations/`, then apply and verify it locally:

```bash
npm run db:check
```

Update the EF runtime mapping and relevant documentation when needed, run the API checks below, review the resulting diff, and commit the migration with its related changes. All eight inventory tables have EF Core runtime mappings; SQL migrations remain canonical. No EF migration or startup schema creation runs.

### Build and regression checks

Use checks relevant to the change. Low-impact defaults/labels generally need a focused local smoke check and existing relevant checks, not a new permanent test file. Add regression coverage for meaningful behavior, security and integrity gaps; see [agent verification guidance](AGENTS.md#verification-scope).

For shared script changes, run `npm run test:scripts`. The database and API check runners share `scripts/redact-secrets.mjs` for printed diagnostics, including exact known secrets when available. Credential provisioning output remains suppressed. The script tests use synthetic strings only.

Build and verify the API:

```bash
dotnet build backend/PhuketSold.Api.Tests
npm run api:check
```

`api:check` runs rollback-only SQL permission/RLS checks and the API tests against actual local PostgreSQL 17.11 using the restricted login. Plain `dotnet test backend/PhuketSold.Api.Tests` runs liveness/failure tests and explicitly skips database-dependent tests unless configured by the runner. The runner uses `--no-restore`, so restore/build first on a fresh checkout.

When changing browse queries, filters or indexes, or investigating a performance issue, include the 10,000-listing query-plan checks:

```bash
npm run db:check:plans
```

This runs the regular database checks plus the synthetic query plans. The ordinary `db:check` command excludes those fixtures. Run broader regression checks before merging substantial changes; passing suites need not be repeated for documentation/formatting-only edits.

For frontend changes:

```bash
npm --prefix frontend run build
npm --prefix frontend test -- --watch=false
```

### Shutdown and hosted environments

Press **Ctrl+C** in the Angular and API terminals. Optionally stop the local Supabase containers:

```bash
npx supabase stop
```

A normal stop preserves the local database; no database reset is required for daily development. The startup, migrations and checks above target local services. Hosted migration pushes and application deployments are separate, explicitly approved operations.

Listing discovery, auth and mutations remain follow-on work. See [supabase/README.md](supabase/README.md) for schema scope, verification, credential recovery and deployment prerequisites.

See [frontend/README.md](frontend/README.md) for the original Angular CLI instructions and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the target architecture.
