# PhuketSold

This repository contains the existing Angular application, a minimal ASP.NET Core 10 API host, Supabase configuration and migrations, and product and engineering documentation.

| Directory | Contents |
| --- | --- |
| `frontend/` | Angular application, including SSR configuration, source, public assets, and npm lockfile |
| `backend/PhuketSold.Api/` | ASP.NET Core 10 API host |
| `supabase/` | Local Supabase configuration and future SQL migrations |
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

The API serves `GET http://localhost:5000/health` with its default HTTP launch profile. Database migrations, auth, and marketplace operations have not been implemented. The `supabase/migrations/` directory is reserved for canonical SQL migrations; no database operation is needed for this scaffold.

See [frontend/README.md](frontend/README.md) for the original Angular CLI instructions and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the target architecture.
