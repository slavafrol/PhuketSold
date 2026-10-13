# PhuketSold — Product specification

**Status:** agreed direction, implementation pending (14 October 2026).
**Market:** Phuket, Thailand. **Product:** mobile-first secondhand marketplace. **Audience:** all local buyers/sellers, initially targeting expats moving into/out of Phuket.

## Positioning

PhuketSold addresses Facebook Marketplace-style friction: sellers cannot easily list an apartment's contents, buyers cannot conveniently negotiate a set of items, stale/sold results remain for months, and recurring searches show the same items. The differentiators are **active inventory, easy batch listing, multi-item offers and alerts on genuinely new matches**. Not every seller needs to be relocating.

**Supply acquisition:** seed concentrated neighborhoods/developments with assisted listing, partnerships with property managers and QR links on building notice boards. Track which sources produce listings, not only scans. Avoid an empty island-wide launch.

## People, identity and languages

- Public browsing, listing pages, seller pages and shareable URLs require no account.
- Creating Sell/Buy listings, chatting, making offers, and saving alerts require **phone OTP OR LINE Login**. No email/password and no mandatory KYC initially.
- Authentication is not a proof-of-trust badge; no badges in V1. Public profile must not leak phone numbers or private identifiers.
- **Contact on LINE** is the initial LINE interaction: if a seller signed in through LINE *and explicitly opted in with a valid public contact handle/link*, show an action to open that contact. LINE OAuth user IDs alone are not add-friend links. If the usable link is unavailable, show internal chat.
- LINE messaging/notification forwarding is a future feature.
- Runtime **EN / TH / RU** switch is available everywhere. Store UI message keys in version-controlled frontend dictionaries; user text translations are separate data.

## Listings

- Two types: **Sell** and **Buy/WTB**. Buy listing uses a **target price** initially.
- Fields: seller, type, title, description, category, price in THB, optional condition, predefined area, optional predefined building/village/development, timestamps, expiry, status; support metadata required for localization/search.
- Maximum **12 images**, with cover selection and reordering. Mobile upload/reorder needs accessible tap controls, not drag-only. Public listing media can be read through CDN, but upload/delete must remain authorized.
- Statuses: `Draft`, `Active`, `Reserved`, `Sold`, `Expired`, `Archived`.
- Default suggested expiry **30 days**. Prompt for renewal before expiry; departure date, if provided, may set an earlier expiry. State transitions are authorized and recorded.
- Only active, eligible listings appear in default results. Expired/sold remain accessible by direct link with obvious state labels and through a seller's **history/archive** view. Do not claim a listing is sold just because an offer was made.
- Stable, SEO/social-friendly listing URL; correct canonical/OpenGraph metadata and no dead links when a listing changes state.

## Multiple items

- Call the generic feature **multi-item sale** (final UX label TBD). It must work for any seller, not only a move-out.
- Seller can create independent items or a group of Sell items; shared draft values such as area, development, dates, and description reduce repeated work. Each item retains its own images, price, status and URL. **Buy/WTB users should also be able to group several wanted items** (a “wanted list”), each with its own target price; keep the data model generic enough to support both without conflating the offer workflows.
- A group has its own shareable URL; buyers can select several available **Sell** items from **any one seller's page**, whether or not they belong to the same group.
- Offer creation on a single listing or multiple selected Sell listings. One bundle offer can cover the selection, with **counteroffers**. Preserve item IDs, listed price snapshots, offer revision/history, buyer, seller and proposed amounts.
- Server must confirm all selected items are eligible, owned by the same seller and not the buyer's own. Seller acceptance can reserve all selected items atomically; it is **not payment**. Handle concurrent acceptance, withdrawal and stale availability explicitly.
- Buy/WTB demand is first-class, but a “seller can fulfill wanted post” flow may be separate from Sell-side bundle negotiations.

## Communication and automatic translation

- Internal chat is **required**; link conversations to parties and optionally a listing/offer/group.
- Send/store the original message immediately. Translate asynchronously to the recipient's selected language, cache translation, and allow viewing original. Translation failure must never block chat.
- Language preference can change; translate to the new language on demand where necessary. Avoid leaking private content into logs or exposing conversations through public APIs.
- LINE contact does not replace internal chat; LINE forwarding and notification integration can be added later.

## Discovery and search

- V1 filters: search text, listing type, category, min/max THB price, Phuket area, optional building/development, sort by newest (additional sorts later).
- Search results contain concise card info and **cover image only**, never a full image gallery. Preserve filters in URL. Sold/expired items do not clutter active results.
- Curate Phuket areas and selected buildings/villages/developments. Offer “Other/not listed” when necessary and avoid exposing home unit numbers. Example areas to validate: Bang Tao/Cherng Talay, Rawai, Chalong, Kata, Karon, Kamala, Patong, Phuket Town.
- Future AI: photo-assisted drafts, suggested titles/categories/prices, fuzzy/semantic search. AI is **not required to ship V1**; structured data remains canonical.

## Saved searches / monitoring (committed follow-on feature)

Use case: somebody spends weeks checking for a MacBook, repeatedly scrolling through unchanged results.

- A user can save the **exact current query + filters**, edit/name/pause/remove it and select notification preference (new matches when feasible or daily digest).
- Near end-of-results, or after extensive/repeated searching, gently offer “Watch this search?” with an **editable confirmation step**. Respect dismissals; do not interrupt browsing or show incessant popups.
- Match **newly published relevant listings**, and record deliveries to avoid telling a user about old inventory again. Show a **“New since last visit”** view and a non-disruptive **“N new listings — show”** bar rather than inserting cards under the scroll position.
- Launch can use scheduled or event-driven matching; avoid promising immediate notifications until delivery capacity exists. In-app delivery first; LINE/other channels later with consent. Schedule and freshness policy remain product decisions to measure.

## Referrals and locations

- Build curated Phuket area and development reference tables, with multilingual labels and aliases. Users choose an area and may optionally choose a known condo/village/building.
- Track source/partner, referral code, campaign URL, QR link visits, signups and published inventory with dedupe/bot suppression and proportionate retention. Example `/sell?ref=partner-code`.
- Potential future development-specific inventory page; do not make it a hard dependency for listings.
- Seed initial supply by offering to photograph/list collections for sellers. Prioritize useful inventory in a geographic cluster and measure actual inquiries/transactions.

## Admin, abuse and privacy

- Operate initial moderation through a restricted **Supabase dashboard**, not a custom admin UI. Later add reports, suspensions, hidden listings and admin interface.
- Design tables/permissions so moderation, reports and audit trails are possible. Rate-limit OTP, messaging, publishing and offers. Prevent spam/impersonation and minimize collection/exposure of contact details.
- No verification badges. Neither phone OTP nor LINE Login constitutes comprehensive seller verification. No payments or escrow in V1.

## Brand and interaction

- Lightweight pastel visual language, colored card borders, mostly **rectangular listing cards**, substantial mobile product photography, clean Airbnb-inspired hierarchy but denser browsing layout.
- Small liquid-glass accents on selected navigation/overlays; subtle hover/card transitions. Reduce effects on mobile; respect reduced motion. Maintain contrast and accessible hit areas.
- Region-dependent theme is a set of CSS **accent tokens**, e.g. Patong green / Rawai sandy yellow. Do not change information hierarchy or accessibility per region.
- Mobile-first, particularly on slower phones and 1–8 Mbit/s networks.

## Proposed milestones (not implementation claims)

| Stage | Shippable outcome |
| --- | --- |
| 0 — Foundation | Reorganized repo, Angular/.NET/Supabase connection, SQL migrations, 3-language UI shell, security/performance baseline, authenticated test flow |
| 1 — Inventory | Public browse/search/listing/seller pages, reference locations/categories, Sell + Buy, lifecycle and image delivery |
| 2 — Publishing | Phone OTP and LINE Login as configured, up to 12 reorderable photos, grouped and individual publishing, expiry handling |
| 3 — Interaction | Single/bundle offers, counteroffers, reservation consistency, internal chat, async translations, opted-in seller LINE contact |
| 4 — Retention / growth | Saved search/alerts, new/unseen inventory, non-invasive alert prompt, QR partner/referral attribution, expiry nudges |
| Later | LINE forwarding/notifications, advanced admin, AI listing help and semantic search, expanded trust/delivery/payment only if validated |

Milestones may overlap through small end-to-end vertical slices; security, localization and performance are **cross-cutting from stage 0**, not separate final polish.

## Metrics and early validation

Track active listings by initial area, distinct sellers, median time to publish a group, batch upload completion, stale-result rate, search-to-contact/offer conversion, successful/failed OTP rates, chat send latency, saved search alert usefulness, referral scan→signup→listing conversion, and real-user loading on slow connections. Do not invent KPI targets without a baseline.

## Open decisions — never silently assume

1. SMS provider/cost/delivery reliability to Thai and international phone numbers; OTP fraud protections.
2. Exact Supabase/LINE OAuth path and whether custom provider integration meets requirements. LINE login identity is separate from *contactability*.
3. Location names and building catalog, including translation/aliases; region-specific color palette.
4. Bundle-offer total versus item allocations, accepted-offer reservation expiry, conflict rules, and the WTB response workflow.
5. Chat translation provider, queue/worker choice, privacy/consent/retention and precise notification channel.
6. Saved-search polling cadence versus event-driven matching, frequency choices and what “new” means for relisted items.
7. Final frontend runtime i18n library, SSR hosting approach, API hosting location, Supabase image-transform plan and whether to keep original uploads.

Record consequential new decisions in `docs/ARCHITECTURE.md` or an ADR; update this product spec when UX contracts change.
