# Frontend agent instructions (`frontend/`)

Inherits root `AGENTS.md`, `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, and `docs/PERFORMANCE.md`.

## Framework and organization

- Angular standalone components and lazy-loaded feature routes. Use the Angular version **actually pinned in this repo**; do not silently upgrade frameworks.
- TypeScript strict mode, SCSS, Angular Signals for local/feature state and `computed` for derivations. Use Angular's `HttpClient`/`httpResource` for appropriate read paths and `HttpClient` for commands. Use RxJS deliberately for debouncing, event streams, and complicated async workflows.
- Do **not** introduce classic NgRx Store/actions/reducers/effects everywhere. Consider NgRx SignalStore only once feature complexity justifies it.
- Group code by feature (browse, listings, multi-item sales, offers, chat, saved search, account, etc.), with `core/` for infrastructure and `shared/` for truly reusable UI/types.
- Public marketplace pages should be shareable and indexable with hybrid rendering/SSR as appropriate. Prevent SSR access to browser-only globals; use platform-safe APIs and avoid duplicate hydration requests.
- Prefer semantic HTML, accessible focus states, keyboard navigation, touch-friendly targets, `prefers-reduced-motion`, and stable layout dimensions.

## UX and visual system

- Visual direction: lightweight pastel theme, clean Airbnb-like hierarchy, rectangular listing cards, more information density than Airbnb, prominent images on mobile, subtle colored borders and glass-like touches.
- Selected Phuket region may update a **small set of CSS design tokens**, e.g. `--region-accent`, `--region-accent-soft`, `--region-border`. Do not create unrelated per-region layouts or compromise contrast.
- Prefer GPU-friendly `transform`/`opacity` animations. Avoid expensive per-card blur/glass, animated layout shifts, and elaborate mobile animations.
- Responsive product images: proper intrinsic width/height/aspect ratio, `srcset`/`sizes`, optimized formats, lazy load off-screen photos. Each search card displays **only the cover**. Never preload all 12 listing photos.
- Search state should be URL-addressable (filters, sort, query) so links, browser navigation, SSR and saved searches share the same canonical representation.
- Preserve scroll position when showing fresh results. Present a user-controlled "new listings" action rather than unexpectedly inserting rows into a scrolled list.
- Saved-search CTA must be contextual and non-invasive. Allow editing search criteria before confirmation; do not repeatedly nag the same user.

## Localization

- English (`en`), Thai (`th`), Russian (`ru`) are required from day one. All UI copy uses translation keys, including validation, errors, metadata and notifications.
- Keep dictionaries in version control, e.g. `src/i18n/en.json`, `th.json`, `ru.json` (or feature-split runtime JSON bundles). New keys must be added to all three; do not silently fall back forever to English.
- Use a runtime language-switching solution selected for this codebase, not three separate deployments. Prefer lazy loading of feature dictionaries.
- Persist user language preference; anonymous users may choose language locally. Handle variable text widths and Thai word wrapping; never encode UI meaning solely through color.
- **User-generated message translation is not UI i18n**; original chat content remains authoritative, with translated versions fetched later.

## Network and state

- Consume marketplace operations only through typed .NET API clients; Supabase browser SDK may be used for auth and specifically approved Storage upload flow.
- Support cancellation/debounce for text search, request de-duplication, explicit loading/error/empty states, and optimistic changes only when rollback is safe.
- Keep above-the-fold JS and image transfers small; lazy-load chat, editor, alerts, offer flows, and noncritical components.
- Do not store secrets or server-role keys in JS bundles or SSR-visible HTML. Handle sessions safely and do not leak private data into SSR transfer caches.
- Use `track`/stable IDs for repeated cards and image frames to prevent expensive DOM churn. Avoid N+1 API calls per card.

## Before marking complete

Run the frontend build, relevant lint/typecheck/tests if configured. Manually or automatically verify mobile breakpoints, 3 locales, empty/error/loading states, and reduced-motion considerations for changed UI. Report untested cases explicitly.
