# PhuketSold — Architecture and engineering decisions

**Status:** initial target architecture (14 October 2026). This is a design contract, not a statement that code already exists.

## 1. Guiding principles

1. **Perceived speed on 1–8 Mbit/s connections** takes priority over clever abstractions or cosmetic effects.
2. Keep a **small modular monolith**: one Angular client, one .NET API, one PostgreSQL database, Supabase-managed auth and media.
3. Centralize domain rules server-side. Use relational constraints and transactions for invariants; avoid duplicating business rules in browser state, RLS and triggers without a purpose.
4. Keep provider integrations replaceable where possible; introduce queues/AI only when features justify them.
5. Preserve SEO, direct links and multilingual accessibility for public marketplace pages.
6. **Version the database schema with SQL migrations only**; never maintain parallel EF schema migrations.

## 2. Repository shape

```text
PhuketSold/
  AGENTS.md
  docs/
    PRODUCT.md
    ARCHITECTURE.md
    PERFORMANCE.md
  frontend/
    AGENTS.md
    ... Angular workspace files at this level ...
  backend/
    AGENTS.md
    PhuketSold.Api/
      Features/
        Listings/
        ListingGroups/
        Offers/
        Chat/
        Search/
        SavedSearches/
        Accounts/
        Referrals/
      Infrastructure/
      Data/
      Program.cs
    ... backend tests and solution ...
  supabase/
    AGENTS.md
    migrations/
    seed.sql
  README.md                 # optional developer quick-start
```

Preserve existing source/history when reorganizing. Do not generate a second Angular workspace or .NET service if one already exists; move/refactor incrementally and fix relative paths and build tasks. Scoped agent instructions should remain small and specific.

## 3. High-level flow

```text
Browser (mobile-first)
  ├─ Angular SSR/hybrid public pages  ─┐
  ├─ Angular interactive client        ├─ HTTPS → ASP.NET Core Minimal API
  ├─ Supabase Auth client login         │               ├─ EF Core → PostgreSQL (Supabase)
  └─ approved direct Storage upload    │               ├─ media upload authorization
       /public CDN image reads         │               ├─ jobs: expiry/alerts/translation
                                       │               └─ future LINE/AI integrations
```

**Boundary:** Angular obtains a Supabase Auth session, attaches its access token to protected .NET requests, and accesses business data through the .NET API. Anonymous read endpoints can be public. Use browser-side Supabase client only where explicitly intended (Auth and controlled Storage upload), not for arbitrary CRUD on application tables. Avoid an API proxy for every image byte: compressed derivatives should go browser ⇄ Storage/CDN.

## 4. Authentication and authorization

- Supported identity methods: **phone OTP OR LINE Login**; at least one to publish/offer/chat/save an alert. No email/password in V1.
- Configure Supabase Auth for phone OTP with a tested SMS provider. Confirm Thailand/international delivery and cost; rate-limit and enforce anti-abuse measures.
- Supabase currently offers **custom OAuth/OIDC providers**, which may support LINE via a validated provider configuration. **Do not assume a built-in LINE provider**. Spike/verify LINE authorization, callback handling, logout and identity mapping before committing to implementation; fallback would require a secure backend integration plan. Document actual approach once proven.
- Verify Supabase-issued API access JWT in .NET using a supported JWT bearer authentication setup (issuer, audience, signature/JWKS, expiry and expected claims). User ID is derived from token claims, never trusted from a submitted form.
- The API authorizes listing ownership, offer participation, conversation membership, saved-search ownership, referral staff operations, image upload paths, and status transitions.
- Separate LINE OAuth identity from a seller's public **opt-in LINE contact link/handle**. Signing in via LINE does not expose a guaranteed user-clickable friend/chat link. Show LINE contact only after user supplies/validates an appropriate destination and explicitly enables it.
- Supabase RLS protects any client-exposed tables/storage endpoints; .NET should use a least-privileged database role and enforce its own domain authorization, with a documented RLS/role interaction. **Service-role keys must never reach browsers.**
- Keep SSR caches/HTML from exposing protected profile, offers, session tokens or chats. Avoid token logging and use cookie/security headers appropriate to the chosen auth flow.

## 5. .NET application design

Use **Minimal APIs organized by feature**, with API boundaries thin and services explicit; this is not one giant `Program.cs` or a 9-project Clean Architecture scaffold.

```text
Features/Offers/
  OfferEndpoints.cs         # route groups, authorization, request/response mapping
  OfferService.cs           # transaction/business rules
  OfferDtos.cs              # immutable transport contracts
  ... optional validation, tests, domain types where justified
Data/
  PhuketSoldDbContext.cs
Infrastructure/
  Authentication/
  Storage/
  BackgroundJobs/
```

- .NET 10 / ASP.NET Core, EF Core with Npgsql for ORM/data access, DI, cancellation tokens, asynchronous I/O and standard errors (RFC 9457 Problem Details if appropriate).
- Read-only projections use `AsNoTracking`, explicit selection, and one browse endpoint returning a complete card DTO. Mutations validate commands, authorize, and use explicit transactions where needed.
- Business rules and input validators belong outside endpoints and outside the Angular client. Database CHECK/FOREIGN KEY/UNIQUE constraints defend invariants at the persistence boundary.
- Structured `ILogger` logging with request/correlation identifiers; never log chat content, secrets, full phone numbers, JWTs or OTPs. Add OpenTelemetry tracing/metrics when monitoring needs justify it.
- Start with explicit in-process interfaces and a simple background worker/outbox. Do not add message brokers or distributed systems before the event volume requires them.

## 6. Domain model — conceptual, not final DDL

| Entity / aggregate | Responsibilities |
| --- | --- |
| `profiles` | User UUID mapped to Auth; display identity, language, contact preferences, optional public LINE contact |
| `areas`, `developments`, `categories` | Curated search/location choices and aliases/translations |
| `listing_groups` | Multi-item grouping for Sell collections **or Buy/WTB wanted lists**; owner, intent/type, shared metadata, shareable slug |
| `listings` | Sell/Buy type, seller, price/target price, area, development, status, expiry, optional group |
| `listing_images` | Storage path, variant metadata, ordering and cover designation |
| `offers`, `offer_items`, `offer_revisions` | Buyer/seller, included Sell listings, total and/or item allocation, counteroffer history/status |
| `conversations`, `participants`, `messages` | Private message membership and original-message delivery |
| `message_translations` | Message ID + target language + provider/version + status/cache |
| `saved_searches`, `search_alert_deliveries` | Saved criteria, user preferences, cursor/event dedupe and notification history |
| `referral_partners`, `referral_campaigns`, `referral_events` | QR attribution, visits and conversion tracking |
| `listing_events`, `reports` | Audit/state history and basic moderation |

Introduce actual tables **incrementally as vertical slices**. Avoid premature general-purpose entity-attribute-value schemas.

### Invariants

- A listing belongs to exactly one account owner (seller for Sell, requester for Buy/WTB) and optionally one listing group owned by that same account; groups must enforce compatible listing intent.
- Buy/WTB price represents a **target**, not sale consideration; Buy users can also create multi-item wanted lists. Multi-item **offer negotiation** initially applies to eligible Sell items; WTB fulfillment uses a separate flow.
- An offer covers one or more Sell items from **the same seller**; an item cannot be reserved by two accepted concurrent offers.
- Counteroffers must retain history and one authoritative current revision/state. Client prices are suggestions; server reads live listing eligibility.
- Prices are integer **THB** amounts, not IEEE floating-point money; timestamps stored in UTC `timestamptz`. UI/local dates are localized to Phuket/user timezone as appropriate.
- Expiration/archival changes **search visibility**, not the stable URL; sensitive details are never leaked from old listing versions.
- Translation failures do not lose the original message.

### Example API surface (illustrative)

```text
GET    /api/listings?q=&type=&category=&area=&development=&maxPrice=&cursor=
GET    /api/listings/{id-or-slug}
POST   /api/listings
PATCH  /api/listings/{id}
GET    /api/sellers/{id}/listings
POST   /api/listing-groups
GET    /api/listing-groups/{slug}
POST   /api/offers                  # one/multiple Sell listings
POST   /api/offers/{id}/counter
POST   /api/offers/{id}/accept
POST   /api/offers/{id}/reject
GET    /api/conversations/{id}/messages
POST   /api/conversations/{id}/messages
POST   /api/saved-searches
GET    /api/referrals/...          # restricted analytics
```

Route shapes are proposals, not pre-existing contracts. Use versioning conventions if/when they earn their cost.

## 7. Database and schema workflow

- **Canonical schema:** versioned SQL in `supabase/migrations/`. EF Core maps the schema and queries it; no EF migration generation and no runtime `Database.Migrate()`.
- Keep schema, indexes, extensions, storage rules and RLS policies in the same reviewed migration history. Write new migrations rather than rewriting already-applied versions.
- Use `supabase migration new ...` locally. Test against **disposable local/dev** databases, seed synthetic inventory, verify API tests and representative SQL plans. Apply to remote only with explicit approval and a migration/rollback plan.
- Supabase dashboard is acceptable for **operational inspection and trusted data moderation**, not untracked remote schema changes. A dashboard schema edit must be captured as a migration before shared deployment.
- Keep extension choices justified: PostgreSQL full text or `pg_trgm` may help early; PostGIS/`pgvector` are future options only when justified by query needs.
- Index based on common `WHERE` + `ORDER BY` access patterns; include ownership and foreign keys. Validate on realistic data with `EXPLAIN (ANALYZE, BUFFERS)` and query logging. Keyset pagination should use stable ordering and tie-breakers.
- Storage policies should constrain paths and ownership for writes. Listing media may be public-read, separate from private chat media. Public bucket = publicly readable bytes, **not** public write.

### Initial inventory schema (2026-10-14)

`20261014015637_initial_inventory.sql` introduces `marketplace.profiles`, categories, areas, developments, listing groups, listings, listing images and listing events. Profiles contain display identity and language only; Auth remains the sole identity/credential store. Opted-in LINE contact destinations/consent will be added with the contact feature, independently of OAuth identifiers. Offers, chat, translations, alerts, referral analytics and reports remain later slices.

`marketplace` is a non-exposed application schema. Do not add it to Supabase Data API exposed schemas. Tables have RLS and no schema/table/function access for `anon` or `authenticated`. Public browsing will use .NET endpoints rather than direct Supabase queries. The migration defines a `phuketsold_api` **NOLOGIN, NOBYPASSRLS** privilege group with explicit table grants and an RLS policy permitting backend access. A dedicated backend login must be provisioned separately; it must not own tables, inherit administrative roles, or be granted to browser-facing roles. This is a trusted server role: .NET must validate phone/LINE authentication, ownership, lifecycle transitions, inactive references, and response visibility on every request. The role cannot delete listings/profiles/groups/events, write events, or edit reference data. Trusted dashboard/migration connections handle curated catalog and moderation operations.

Publishing sets the first publication time and defaults expiry to **30 days**; the API can supply an earlier departure-aware expiry. It must always exclude expired-by-clock inventory using `status = 'active' AND hidden_at IS NULL AND expires_at > statement_timestamp()`, even before an expiry worker runs. Archived/hidden rows are never public; permitted historical sold/expired URLs use an explicit narrow response. Group defaults are copied by the API into independent items, not dynamically inherited. Assigned listing/group slugs, owner, type and primary IDs are immutable. UUID URLs work before a slug is assigned.

Mutable rows receive controlled timestamps and monotonically increasing `version`; API mutations must include owner and expected version in the SQL predicate, returning a conflict if no row matches. Listings automatically append transactional lifecycle/version events. Set `app.actor_id` with `set_config(..., true)` inside each authenticated write transaction after JWT validation; clear/omit it for system maintenance. Events record changed field names rather than historical personal text. Account erasure is deliberately restricted by foreign keys until a separate anonymization/retention workflow exists; no destructive Auth-user cascade is configured.

Image slots `0..11` plus a deferrable unique constraint enforce the twelve-image limit under concurrency. Reorder in a transaction with the position constraint deferred; cover replacement clears the previous cover before selecting another. There is at most one cover; the API falls back to the first ready image if none is selected. Ready media requires thumbnail/card/display paths, and cards select only the required variant of one ready image. Storage buckets, write policies, signed-upload issuance, MIME/dimension/EXIF validation and the processing pipeline are **not implemented** by this metadata migration.

Newest/price keyset indexes, foreign-key indexes and a partial `pg_trgm` GIN index support inventory discovery. Text search uses `lower(coalesce(title, '') || ' ' || description) LIKE @pattern` for multilingual substring matching; the API escapes wildcard characters and bounds searches shorter than three characters (for example, require longer text or sufficiently selective filters). No provider transforms, PostGIS, vectors or text-translation service are assumed. See [Supabase verification and rollout notes](../supabase/README.md) for SQL checks and current validation limits.

Local database development on macOS uses OrbStack with the existing Supabase CLI. `npm run db:check` starts/reuses the local stack, verifies the actual PostgreSQL **17.11** patch version, applies local migrations, lints SQL, and runs inventory/RLS/query-plan verification through the database container's `psql`. The config explicitly selects PostgreSQL major 17. The runner refuses remote container endpoints, captures credential-bearing CLI output, does not reset existing data, and leaves services running between checks. This gives coding agents and developers the same repeatable command without requiring a separate host database/client installation. Hosted migration pushes remain separately authorized operations.

## 8. Angular frontend

- Supported pinned Angular version; standalone, strict TS, SCSS, lazy-loaded routes, Signals for local state and derived values, `httpResource` for appropriate reactive reads, RxJS for streams/debounce, `HttpClient` for mutation operations.
- Avoid defaulting to historic NgRx Store/actions/reducers/effects. Consider NgRx SignalStore only when clear feature state complexity develops.
- Prefer hybrid rendering: **public** landing/listing/group/seller surfaces indexable via SSR/appropriate prerendering; authenticated chat, editors and account dashboards can be CSR. Ensure Angular SSR configuration actually matches the chosen deployment platform.
- Keep server-rendered data public, cache-safe and hydrated without a duplicate fetch when supported. No private Supabase session tokens or private account data in shared render caches.
- Route/query parameters are canonical for browsing filters so bookmarked searches, browser back and saved searches work.
- UI translation keys use runtime EN/TH/RU JSON dictionaries in Git. Lazy-load feature dictionaries when practical. Content translation for chat/listings is **not** mixed into these files.
- Design system: regional accent CSS variables + neutral/pastel base; SCSS tokens/mixins only where useful; one consistent set of components. Reduced motion, color contrast, semantic HTML and mobile layout are non-negotiable.

## 9. Images and Storage

- Client resizes/compresses to practical upload sizes when safe; server/storage validates mime, dimension and limits. Strip EXIF/geolocation unless demonstrably needed. Never trust client metadata alone.
- Max 12 images per listing, stored with stable UUID-based paths. Persist cover and ordering explicitly (not inferred from upload time).
- Plan responsive variants around ~320px thumbnails, ~640px cards and ~1280px details, with actual encoder quality/format tuned by visual tests and Supabase plan economics. WebP primary where compatible, optional AVIF and JPEG fallback.
- Search loads only **one cover thumbnail per visible card**; listing detail loads initial hero and defers other photos. Provide width/height/aspect ratios to prevent layout shift and avoid downloading originals for grids.
- Listings and derivative images may be in a **public-readable** bucket so browsers/CDN cache. Anyone with the URL can view them, including after seller removes a link until cache expiry; do not put private/proprietary data there. Store private chat images separately.
- For uploads, use direct browser-to-Storage transfer with policy enforcement/signed upload where authorized; .NET returns safe upload instructions and finalizes/validates ownership. Do not proxy megabytes of image data through the app API.

## 10. Async tasks and integrations

- **Chat delivery:** commit original and respond promptly; schedule translation work with dedupe. Present original while translation is pending; cache by message/language/version, allow failure/retry without duplicate message sends.
- **Expiry:** scheduled reconciliation moves overdue active items to expired, with reminder handling and idempotency.
- **Saved search alerts:** trigger on publication or batch match recent listings, dedupe with a delivery table, obey user preferences and throttle digests. No repeated scans of every saved search every second; optimize when actual scale warrants it.
- **Referrals:** count meaningful visits/conversions with bot filtering and limits; never block the listing page on analytics writes.
- **LINE:** V1 optional contact outbound link for opted-in LINE-authenticated sellers; future OAuth-linked official-account notifications/forwarding need explicit consent and LINE platform capabilities. Do not assume login grants permission to DM a user's personal LINE account.
- **AI:** later bounded asynchronous suggestions/search enrichment through a provider interface; keep raw user data minimized and human-editable, never blocking publishing.

## 11. Testing, delivery and observability

- Tests: unit tests for offer and lifecycle rules; API integration tests against Postgres for query correctness/RLS/transactions; end-to-end tests for publish, chat, search, auth, and multilingual flows.
- CI: Angular lint/typecheck/build and .NET build/tests, SQL migration lint/local smoke where feasible. Use synthetic test users/data; secrets in CI secret store only.
- Each feature includes loading/error/empty states and disabled/poor-network handling. Measure Core Web Vitals, page/image payloads and API latency with slow-network throttling.
- Deploy API/database close enough to avoid significant origin RTT; confirm actual Supabase regional options and hosting, not assumptions. Use HTTPS, CORS allowlist, configured forwarded headers, connection pooling and observability before public beta.
- No premature microservices, Kafka, Redis, complex event sourcing or giant architecture layers. Add them only when measurements or correctness demand them.

## 12. Architecture decisions register

| Decision | Current choice | Why |
| --- | --- | --- |
| Client | Angular + SCSS + Signals | Familiar scalable frontend; less boilerplate, SSR options |
| Business API | .NET 10 feature-based Minimal APIs | Owner knows .NET; clear domain-rule boundary and testability |
| Data store | Supabase PostgreSQL | Relational transactions, managed operations, future search flexibility |
| Auth | Supabase Auth phone OTP + validated LINE custom OAuth/OIDC approach | Low friction; no passwords |
| Media | Supabase Storage + CDN and responsive derivatives | Low latency and cheap image delivery |
| ORM/schema | EF Core runtime **plus canonical SQL migrations** | Code-based querying, one source for Postgres/RLS/indexes |
| Localization | Runtime EN/TH/RU dictionaries | In-app switching with one deploy |
| Chat translation | Async jobs, original first | Avoid request latency and translator outages |
| Global state | Signals first, NgRx SignalStore if needed | Minimize complexity |
| Rendering | Hybrid SSR/CSR (to validate with host) | Public SEO/shareability plus interactive app |
| Deployment | Supabase selected; frontend/API hosting TBD | Avoid premature vendor lock-in |

**References (authoritative starting points):**

- [Angular hybrid rendering](https://angular.dev/guide/hybrid-rendering)
- [Angular `httpResource`](https://angular.dev/api/common/http/httpResource)
- [ASP.NET Core APIs overview](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/apis?view=aspnetcore-10.0)
- [Supabase SQL migrations](https://supabase.com/docs/guides/deployment/database-migrations)
- [Supabase custom OAuth/OIDC](https://supabase.com/docs/guides/auth/custom-oauth-providers)
- [LINE account linking](https://developers.line.biz/en/docs/messaging-api/linking-accounts/)

Review documentation when implementing integration points, because provider capabilities and pricing change.
