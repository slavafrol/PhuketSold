# PhuketSold — Performance engineering contract

**Priority:** first-class product requirement. Phuket users may browse on **1–8 Mbit/s** connections, elevated RTT, intermittent coverage and modest mobile devices. A feature is incomplete if it works only on fast Wi-Fi. Optimize **time to useful inventory**, not synthetic throughput alone.

## 1. Real-world implications

At 1 Mbit/s the theoretical throughput is about **125 KB/sec before overhead**. A 2 MB image can easily dominate a page for many seconds. The biggest wins are the size and priority of resources, fewer round trips, effective caching, and rapid first render—not choosing Minimal APIs over controllers for a few milliseconds.

### Starting budgets (targets to tune, not guarantees)

| Surface | Initial target | Notes |
| --- | --- | --- |
| Search page JSON | ≤ 40 KiB transferred/compressed for 20–24 cards | No full descriptions, image arrays or seller subresources |
| Small search thumbnail | ~15–35 KiB typical at ~320 px | Allow reasonable variation by photographic content |
| Main grid card image | ~30–70 KiB typical at ~640 px | Actual `srcset`/`sizes` picks smallest useful file |
| First viewport | Prioritize 4–8 visible covers, not all page images | Adjust to screen/grid geometry |
| Cards per page | ~20 (tune 20–24) | Cursor pagination, not unbounded inventory |
| Critical route JS | Set/monitor build budgets; minimize first-route chunks | Do not quote a universal size without a real build baseline |
| Slow-network render | Aim for useful text/skeleton + first relevant cards quickly | Test 1, 2 and 8 Mbit/s with high RTT, cold cache and midrange CPU |
| Layout stability | Reserve dimensions; minimize CLS | Never let delayed gallery/carousel cause jumps |

Budget measured **as transferred**, not source-file size. Track main-thread CPU cost and JavaScript execution as well as bytes. File sizes are guideposts for implementation and should be adjusted from measured visual quality and real-user behavior.

## 2. Images: the highest priority

- Optimize *before* first use. Never serve an original iPhone 5–20 MB upload as a grid card. Reject unsupported/malicious payloads, cap dimensions/bytes and verify encoded result server-side or through an approved controlled pipeline.
- Use responsive **~320 / 640 / 1280 px** variants as starting sizes, and browser `srcset`/`sizes` to prevent downloading an oversized version. WebP is a practical baseline, optional AVIF with tested fallback. Compress intelligently; human-check product detail legibility.
- First grid request loads **cover only**. Images 2–12 are not fetched until detail/gallery interaction; detail can preload the next image only when justified.
- Lazy load images below viewport; load the hero/LCP image with appropriate priority. Do not lazy-load an above-the-fold LCP image.
- Supply intrinsic dimensions/aspect ratio; display light placeholders or dominant-color backgrounds. No distracting shimmer/blur on low-end phones.
- Prefer direct CDN URLs with long-lived immutable asset paths, cache headers and content hashing/versioned names; when a seller replaces an image, use a new object path instead of assuming immediate CDN invalidation.
- Avoid cache-busting signed URLs on **public listing images**. Do not publish private attachments in the public bucket. Strip EXIF GPS where applicable.
- Prefer browser → Storage for authorized uploads; generate/resize variants through an approach affordable on the chosen Supabase plan. Supabase managed image transforms can be plan-dependent: do not assume paid transforms are free.
- On poor networks, indicate upload progress and allow orderly recovery; do not upload 12 originals at once and saturate the user's connection. Upload with bounded concurrency (often 1–2 on slow networks), and keep editing possible while uploading.

## 3. Angular / critical rendering path

- Public home, browse and listing/group pages should be crawlable and useful via **hybrid SSR or appropriate prerendering**. Private chat/account/editor pages can be CSR; verify with actual deployed hosting.
- Route-level lazy-load chat, editing, advanced filters, gallery extensions and other noncritical code. Translation dictionaries should load by current language/feature when practical.
- Favor Signals + local derived state; limit change detection and DOM work with stable list tracking. Avoid expensive global stores without clear need.
- Search input debounces and cancels superseded requests; no request for every keypress. Preserve the last useful results during updates when safe.
- SSR must not accidentally trigger duplicate browser fetches on hydration; use Angular's supported transfer mechanisms only for safe public data.
- Prevent blocking font downloads (font-display, efficient character subsets if suitable for Thai/Russian), huge icon libraries, third-party trackers, heavyweight carousel dependencies and client-only rendering waterfalls.
- Animations use `transform`/`opacity`; minimize `backdrop-filter`, shadows and motion on mobile; honor reduced motion. Browser interaction remains responsive even when images decode.
- Use skeletons/placeholder frames with fixed dimensions, meaningful text early and progress feedback. Provide retry/offline-friendly messages for network failures.

## 4. API and database requests

- `GET /api/listings` returns **one narrow card list**, including title/price/status/location and *cover variant* only. Do not fetch seller/area/image separately for each card (N+1).
- Minimize JSON field names/duplicate representations where reasonable, but clarity beats brittle micro-optimization. Enable HTTP compression (Brotli/gzip where appropriate); do not compress already-compressed images.
- Keyset/seek pagination with stable sort and cursor binding to filters. Avoid ever-growing `OFFSET`, full result materialization and broad `SELECT *`.
- Index real browse predicates (eligible status, type, category, area, development, price, publish time) based on workload. Join reference tables safely and measure actual query plans. Use a capped text-search approach; avoid a full table scan for every keystroke.
- Cache near-static location/category data at CDN/app/client layers with clear invalidation; translations/assets should be versioned and cacheable. Keep listings short-cache or event-invalidated as freshness demands.
- Minimize redirects and page-level request waterfalls; public browse should require as few critical API calls as possible.
- Keep Supabase Postgres and the .NET API in a nearby suitable region; test **actual** round-trip times from Phuket and connection-pool behavior before choosing final deployment.
- Do not block listings/offers/chat HTTP responses waiting for translation, AI suggestions, notification delivery, referral analytics or expiry reconciliation. Queue async work and handle retries/idempotency.

## 5. Search freshness without disruption

- Initial result order is stable. Cursor pagination must not duplicate/miss items due to same timestamps; use a tie-breaker ID.
- Do **not** automatically inject matching new listings into the top of the current scroll view. Show a small "N new listings" control that the user can activate.
- Saved searches should use deduped matching on new publication events or appropriately sized batches, not polling every user filter every second. Alert only on relevant *new* results and respect schedule preferences.
- Show saved-search prompts only contextually and sparingly; dialog/network work should never block continued scrolling.
- Sold/expired items disappear from active search by status filter; archived URL and seller history views may be cached separately with correct visibility rules.

## 6. Media, auth and chat reliability

- Authentication should not be a prerequisite for public content loading. Avoid an auth-session round trip before showing the first public card.
- Phone OTP flows need timeout/retry/rate-limit UX and clear feedback. Never include OTPs/tokens in logs, analytics or query strings.
- Use client upload progress and cancel/timeout behavior. After partial upload, provide a safe cleanup strategy so abandoned variants do not accumulate indefinitely.
- Chat shows the **original message immediately**; translated version updates asynchronously. A user should still be able to read and respond if translation is late/offline.
- Translation caching respects language changes, original edits (if later permitted) and data deletion/retention policy.
- Optional LINE links are normal browser intents and should degrade safely if LINE is not installed. Do not rely on them for critical chat delivery.

## 7. Measurement and release gates

Test against at least:

1. ~**1 Mbit/s**, elevated 300–800 ms round-trip, throttled midrange mobile CPU, **cold cache**.
2. ~**2–3 Mbit/s**, intermittent/high latency, warm cache.
3. ~**8 Mbit/s**, real-world mobile and desktop, cold/warm cache.
4. Low-end Android and mobile Safari layouts, including slow image decoding and portrait scrolling.
5. English, Thai and Russian: Thai wrapping/font metrics, Russian text lengths and layout expansion.

Measure: LCP, INP, CLS, Time to First Byte, transferred bytes by type, JS execution, search-to-first-useful-card, image decode, per-endpoint latency and p95 database query time. Use Lighthouse/WebPageTest or equivalent plus actual DevTools throttling and (later) consent-conscious real-user monitoring. Test with realistic **20+ item** pages and 12-photo detail pages; empty test pages are not representative.

### Agent acceptance checklist for a changed feature

- Does the first screen work on the simulated 1 Mbit/s profile without unnecessary assets or blocking API chains?
- Does the listing grid fetch only cover variants, and does image sizing prevent layout shift?
- Are browse DTOs projected, SQL filters server-side and pagination bounded?
- Can requests be canceled/retried safely? Do errors/slow states remain usable?
- Do translation/localization choices increase critical bundles unnecessarily?
- Is accessibility/performance preserved in all 3 languages and on phone widths?
- Did the change alter a measurable budget? If yes, show before/after and justify.

Performance targets are engineering guardrails, not license to reduce product-image quality until items become impossible to judge. Evaluate tradeoffs with real mobile devices and representative Phuket conditions.
