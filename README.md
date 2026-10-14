# PhuketSold

This repository contains the existing Angular application, a minimal ASP.NET Core 10 API host, Supabase configuration and migrations, and product and engineering documentation.

| Directory | Contents |
| --- | --- |
| `frontend/` | Angular application, including SSR configuration, source, public assets, and npm lockfile |
| `backend/PhuketSold.Api/` | ASP.NET Core 10 API host |
| `supabase/` | Inventory schema migration, local sample catalog, verification SQL and Supabase configuration |
| `docs/` | Product, architecture, and performance documents |

## Local development

Prerequisites: Node.js 24, npm 11, and .NET SDK 10.

```bash
cd frontend
npm ci
npm start
```

The Angular dev server serves `http://localhost:4200/`. To build the Angular browser and SSR output, run `npm run build` from `frontend/`.

In a separate terminal, run the API host:

```bash
dotnet run --project backend/PhuketSold.Api
```

The API serves `GET http://localhost:5000/health` with its default HTTP launch profile. The initial inventory schema is defined in `supabase/migrations/`; API database access, auth, and marketplace endpoints have not been implemented. See [supabase/README.md](supabase/README.md) for schema scope, local verification, and deployment prerequisites.

For local database development on macOS, install/open OrbStack once, then run `npm run db:check` from the repository root. It starts/reuses local Supabase, requires PostgreSQL 17.11, and runs migrations, SQL lint and inventory checks using the database container's SQL client.

See [frontend/README.md](frontend/README.md) for the original Angular CLI instructions and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the target architecture.
