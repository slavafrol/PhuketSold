# Backend agent instructions (`backend/`)

Inherits root `AGENTS.md` and documents in `docs/`.

## Service shape

- ASP.NET Core / .NET 10 modular monolith with **feature-organized Minimal APIs**. Keep `Program.cs` as composition/wiring only.
- Example feature directory: `Features/Listings/{ListingEndpoints,ListingService,ListingDtos}.cs`. Shared cross-feature concerns can live under `Infrastructure/`, `Data/`, `Auth/`, or `Common/` when justified.
- Use DI and clear application-service boundaries. Endpoints parse/validate/authenticate and map responses; services implement business rules; database operations are explicit and testable.
- Use EF Core + Npgsql for runtime access to Postgres; migrations remain canonical SQL under `supabase/migrations/`. **Do not add EF migrations or call `Database.Migrate()`**.
- Return narrow, versionable DTOs rather than database entities. Use standard HTTP semantics, a consistent error shape (Problem Details), cancellation tokens, pagination, and explicit validation.

## Security and correctness

- The .NET API verifies Supabase-issued JWTs (issuer, audience, signature, expiry) with supported middleware and current provider configuration. Never trust a user ID, seller ID, role, or price supplied by the client without checking authorization and authoritative database state.
- Public browsing may be anonymous; publishing, offering, messaging, saving alerts and editing require a valid user session. Rely on server-side authorization for every mutation.
- Handle seller ownership, single-seller multi-item offer constraints, allowed status transitions, amount validation, counteroffer permissions, and concurrency in transactions. Decide explicitly whether accepted offers only reserve stock or can coexist with other pending offers.
- Use database transactions for operations spanning offers/offer_items/reservations and other correlated writes. Use consistent idempotency for retry-prone endpoints (offer creation, messages, notification jobs).
- Avoid using the Supabase service-role key for routine browser access. If server operations have elevated DB permissions, API authorization and/or RLS strategy must be explicit and tested; service-role bypass is not a substitute for checks.
- Never log JWTs, OTPs, secrets, private chat text, full phone numbers, or sensitive personal data. Use `ILogger` structured fields with correlation/request IDs.
- Rate limit login-related, messaging, offers, reporting, and other abuse-prone actions. Use safe errors and input/output validation; do not disclose whether a private account exists.
- LINE Login and phone SMS provider need actual integration validation. LINE provider OAuth user ID is not a messageable personal contact URL; collect/validate an optional public LINE handle/link separately with seller consent.

## Performance and reliability

- Keep browsing/search one round trip returning 20–24 **lean listing card DTOs** with cover thumbnail metadata, not full listings or gallery arrays.
- Use seek/keyset pagination for deep result pages with stable ordering (`created_at`, `id` or ranking+tie-breaker); validate cursor/filter compatibility.
- Query only needed columns; project to DTOs; `AsNoTracking` for read-only EF Core queries; avoid N+1 queries. Evaluate indexes and `EXPLAIN (ANALYZE, BUFFERS)` on representative data.
- Filter/sort/search in SQL, not in memory. No synchronous AI or translation work in latency-sensitive request paths.
- Keep transactional request handlers short; asynchronous outbox/queue pattern when introducing notifications or translation jobs. Implement retries with deduplication and backoff, not unbounded loops.
- Avoid routing image bytes through .NET. Authorize uploads, then upload directly to controlled Supabase Storage paths with appropriate policies/signed upload tokens; serve listing derivatives from CDN.
- Deploy API compute reasonably near the Supabase Postgres region; protect connection pooling and avoid opening new database connections per card.

## Tests

Cover important states and boundaries: auth, ownership, status/expiry, offer/counteroffer transactions and race conditions, pagination stability, permissions, validation, translation-job failure, and referrals attribution. Run `dotnet build` and relevant `dotnet test` when implementing code; describe missing setup if tests cannot execute.
