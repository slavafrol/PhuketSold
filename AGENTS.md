# PhuketSold — Instructions for coding agents

Scope: the entire repository. More specific `AGENTS.md` files in `frontend/`, `backend/`, and `supabase/` add requirements for those directories. Do not replace the scoped instructions with this file.

## Read first

Before substantial work, read the relevant portions of:

1. `docs/PRODUCT.md` — product behavior, user journeys, feature priorities, acceptance criteria.
2. `docs/ARCHITECTURE.md` — boundaries, auth, data contracts, infrastructure, design decisions.
3. `docs/PERFORMANCE.md` — hard constraints and performance budgets for 1–8 Mbit/s users.
4. Any `AGENTS.md` files under directories being modified.

Read targeted sections rather than repeatedly dumping entire files into context. When behavior or architecture changes, update the appropriate document in the same change.

## Product invariants

- PhuketSold serves people in Phuket, especially expats moving in/out, without excluding ordinary secondhand trade.
- Both **Sell** and **Buy / Wanted** listings exist; Buy listings use a target price initially.
- Users can create independent listings and convenient multi-item groups: **Sell** collections (“multi-item sale”) and **Buy/WTB** wanted lists; neither is limited to moving out. Buyers can bundle-offer on eligible Sell items belonging to one seller.
- Buyers can offer on a single listing or multiple items belonging to the same seller, with counteroffers.
- Seller inventory has `Draft`, `Active`, `Reserved`, `Sold`, `Expired`, and `Archived` states. Do not show sold/expired items in active search, but preserve direct URLs and seller history where appropriate.
- Internal chat is required; translating messages is asynchronous and must never block delivery.
- The UI supports English, Thai and Russian from its inception, including runtime language switching.
- Publish/offer/message operations require **phone OTP OR LINE Login**. Browsing is public. No email/password and no mandatory KYC in V1.
- A Contact on LINE action is shown only when an opted-in seller has a valid, explicitly supplied LINE contact destination. LINE OAuth identifiers alone are **not** public LINE handles.
- Allow 12 images per listing, reordering and choosing the cover; listing cards load only the necessary thumbnail.
- Areas and selected villages/condominiums/developments are curated reference data; QR/referral links are attributable to acquisition partners.
- Search supports text, category, listing type, area, optional development, price, sorting. Saved searches and new-match alerts are planned, including a non-intrusive opt-in after deep browsing.

## Stack and boundaries

- Angular (current supported version pinned in the repo), standalone components, Signals where useful, SCSS, SSR/hybrid rendering for public discovery pages.
- ASP.NET Core / .NET 10, a **modular monolith** using feature-organized Minimal APIs, not microservices.
- Supabase-hosted PostgreSQL, Supabase Auth, Supabase Storage; SQL migrations in `supabase/migrations/` own the schema. EF Core is for runtime data access, not schema migrations.
- Angular calls the .NET API for marketplace business operations. Direct access to Supabase from the browser is limited to supported auth flows and explicitly authorized media uploads/downloads; do not expose service-role keys or turn the browser into a second business-logic layer.
- Hosted providers and image-transformation capabilities are provisional; don't hard-code provider-specific assumptions into business logic unnecessarily.

## Work style

- Prefer small, coherent vertical slices that build and can be tested. Avoid speculative frameworks, premature generic abstraction, microservices, and heavyweight global state.
- Optimize for perceived speed on **1–8 Mbit/s** mobile networks, small payloads, minimal round trips, and readable mobile layouts. Treat performance regressions as bugs.
- Always cover authorization, validation, concurrency/idempotency when relevant, pagination, empty/error/loading states, and localization keys in feature work.
- Prefer existing project conventions. Add major dependencies only with approval, after explaining purpose and maintenance cost.
- Write concise, explicit types and meaningful names. Comment **why** a non-obvious choice exists; don't narrate obvious statements. Use structured logging for significant events, with redaction of personal information and secrets.
- Never fabricate an integration working: LINE Login, SMS provider, Supabase configuration and notifications require real credentials/provider setup and validation.
- Never paste or commit secret values, access tokens, OTPs, private message bodies, or personal phone numbers. Keep configuration in environment/secret storage; provide `.env.example` with placeholders only when creating config.

## Permission boundary

Allowed without asking: inspect source, create/change feature code and docs, run formatting/build/lint/tests, run read-only commands, make safe local development changes.

Ask before: destructive/irreversible database operations; deleting significant project code/data; writing to real hosted/production environments; deployments; credentials changes; bulk user messaging; changing auth/security assumptions; introducing major dependencies; performing costly third-party API calls. Do not run `supabase db reset`, `db push`, or destructive SQL against shared/remote databases without explicit approval.

## Completion contract

For each coding task, provide a **short** report:

- Changed files and behavior.
- Tests/build/lint executed with results (or specifically why they could not run).
- Migrations/configuration/manual setup, if any; identify operations **not** executed.
- Security/performance considerations if relevant and unresolved issues.

Do not claim a successful build, live deployment, or end-to-end integration without verifying it. Use concise technical explanations: the project owner is an experienced web developer.
