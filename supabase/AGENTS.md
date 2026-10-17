# Database / Supabase agent instructions (`supabase/`)

Inherits root `AGENTS.md` and documents in `docs/`.

## Source of truth

- `supabase/migrations/*.sql` are the **only canonical application schema migrations**. Never create parallel EF Core migrations or manually edit the hosted database schema outside the documented migration workflow.
- Migrations must be ordered, forward-only for deployed environments, reviewed, and tested locally before shared deployment. Do not edit an already-applied migration; write a new one.
- Keep development/test seeds in `supabase/seed.sql` or explicit seed files; they must contain invented/sample data only, not real phone numbers or user chat.
- Agents must **ask first** before `supabase db reset`, `supabase db push`, dropping tables, deleting hosted data, or applying migrations to remote instances. `db reset` destroys local database content; never run it without confirmation about the target.

## Model essentials

- Auth identity lives in `auth.users`; public profiles are mapped by stable user UUID. Support phone OTP or LINE Login, not email/password.
- Core planned entities include: profiles, listing groups (multi-item sales), listings (Sell/Buy), listing images, categories, areas, developments/buildings, offers, offer items, offer revisions/counteroffers, conversations, participants, messages, message translations, saved searches, alert deliveries, referrals/partners, QR visit events, listing lifecycle/audit events and moderation/report records. Add tables incrementally, not all up front.
- Distinguish a **generic multi-item group** from an account's whole catalog; support Sell collections and Buy/WTB wanted lists. Allow bundle offers on eligible Sell listings owned by the same seller, even across groups.
- Enforce ownership/uniqueness/foreign keys/checks/valid states in SQL where practical. Use UTC `timestamptz`, explicit monetary integers in THB (and later currency metadata only if needed), case-normalized indexes/constraints where appropriate, and stable immutable primary keys.
- Every mutable business entity needs controlled `created_at`/`updated_at` semantics, soft-delete/archive where product history requires it, and an audit trail for sensitive mutations.

## Security model

- Keep RLS enabled on client-accessible application tables and Storage objects as applicable, even if main application CRUD is via .NET. Document any intentionally privileged backend role and its checks.
- Public may read published active inventory and permitted historical listing views; never expose private messages, offer amounts, phone numbers, contact preferences, owner-only archives, or moderation data through public views.
- Public listing media may use a readable bucket for fast CDN delivery; restrict upload/update/delete to authorized users and controlled paths. Private chat/media attachments use separate restricted storage.
- Treat LINE ID used for authentication and opt-in seller LINE contact target as different fields/concepts. Never expose provider tokens or user identifiers as contact links.
- For referral events, collect minimal data, prevent easy duplicate inflation, set retention limits and avoid unnecessarily storing raw IP addresses.

## SQL performance

- Search queries must filter by type/status, location/development, category and price efficiently; use indexes designed from representative `WHERE`/`ORDER BY` plans, not blind combinations of every column.
- Prefer keyset pagination with composite indexes matching query order. For text/fuzzy search use PostgreSQL FTS/`pg_trgm` when justified; vector search/PostGIS are future options, not launch dependencies.
- Avoid unbounded scans and count(*) on huge tables for every browse request; optimize aggregate endpoints independently.
- Index foreign keys and common ownership/status filters as appropriate; measure insert/update costs from new indexes.
- Write critical offer/stock operations with transactional integrity and explicit race/concurrency protections.

## Operational checks

For schema changes provide a concise migration note, any necessary backfill/rollout, rollback considerations, and verification SQL. Test on local/dev data, check RLS policies for both anonymous and authenticated roles, and consider query plans/affected row counts before production rollout.

Follow the root verification-scope rules. Verification SQL may be a one-off local smoke query; a new migration does not require a permanent script. Extend existing checks for meaningful behavior/integrity changes, and keep rollback-only synthetic fixtures. `npm run db:check` covers migration/lint/integrity/RLS checks; `npm run db:check:plans` additionally runs the synthetic query plans when query/index/performance changes justify them.
