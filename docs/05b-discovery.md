# Phase 5b — Screen Definitions: Discovery

Status: for approval · Conventions: [05-index](05-screen-definitions-index.md) · Routes: [Phase 4 §4.2](04-navigation-flow.md)

12 definitions (the surface map's 10, plus the zero-result split in §5b.12 / amendment A10).

> Amendments to earlier phases: **A8** (§5b.1) · **A9** (§5b.10) · **A10** (§5b.12).

---

## Area decisions

Recorded once; referenced by the screens below.

| # | Decision | Rationale |
|---|---|---|
| **D-b1** | **The feed is sectioned by pickup urgency** — *Collect now* → *Later today* → *Tomorrow* — sorted by distance within each section. | Pickup time is the dominant decision axis in a time-boxed marketplace. A bag collectable at 9:30 pm is worthless to someone who wants dinner now, however close it is. A flat distance sort buries the only bags a user can act on immediately. Sort control can override to flat. |
| **D-b2** | **Map pins are merchants, not bags.** | One merchant may list three bags; bag-level pins would stack at a single address and be unclickable. |
| **D-b3** | **List is the default view, not the map.** | Faster, scannable, accessible, and it avoids a maps-SDK session charge on every app open (Phase 1 unit economics). Map answers a narrower question — *"is this on my way?"* |
| **D-b4** | **Search does not index bag contents.** Scope is merchant name, category, food-type tag, and locality. | A direct consequence of Surprise-Bag-only: contents are undisclosed, so there is nothing to index. A user searching *"kaju katli"* would otherwise get a bare zero-result screen and conclude the app is empty. The search screen must set this expectation explicitly (§5b.3). |
| **D-b5** | **Changing the dietary facet in the filter sheet is session-scoped and never overwrites the stored acceptance set.** | The stored set is a religious/ethical constraint captured deliberately in §5a.5. A one-off widening to browse must not silently and permanently reconfigure it. Changing it for good is a Settings action, not a filter action. |
| **D-b6** | **A per-customer cap of 2 bags per listing.** | Without it one user can clear a merchant's entire surplus, starving the marketplace and defeating the merchant's reason to list. See A9. |

---

## 5b.1 Discover (list) — `/discover?<facets>`

**Purpose.** Turn a location and an acceptance set into a ranked list of bags the user can actually
go and collect. The primary surface of the product.

**User goals.** Find something good, near, soon, at a price that feels like a win — and decide fast.

**Components.**

| Region | Contents |
|---|---|
| App bar | Location chip (→ §5b.6) · search · notification bell with badge |
| Facet bar | **Visible dietary indicator** (§4.5 — what narrows results is always legible) · filter chips showing active facets · sort · list/map toggle |
| Body | Urgency sections (D-b1) of bag cards · pagination · pull-to-refresh |
| Overlays | Stale banner *"as of 7:42 pm"* (§2.5) · **active cart-hold countdown banner** (§4.7) |

**Bag card.** Storefront thumbnail · merchant name and category · bag title · **dietary mark with text
label** · price, struck-through retail value, discount % · distance · pickup window · scarcity cue ·
merchant rating.

**States.** `initial`/`loading` (skeleton cards matching final geometry) · `loaded` · `refreshing` ·
`paginating` · `paginationError` (inline retry row, existing results retained) · `stale` · `offline` ·
`empty` → §5b.12 · `error`.

**Empty states.** Three distinct states, never one — see §5b.12 and A10.

**Error states.** Per §C5. Offline with cache → cached content plus banner; offline without cache →
the offline empty state with retry.

**Validation.** Facet parameters arriving from a URL are **sanitised, not trusted**: an unknown
category is ignored rather than 404'd, `maxKm` is clamped to the allowed set, malformed values fall
back to defaults. Deep links arrive from shared URLs, old app versions, and week-old notifications;
none of those should produce an error screen.

**Accessibility.**

- A bag card is **one merged semantic node** with a front-loaded composed label, ordered by what
  decides the tap: *"Bakery Surprise Bag, Sweet Crumb. Pure vegetarian. ₹120, was ₹350, 65% off.
  1.2 km. Collect 8 to 10 pm. Only a few left."*
- A struck-through price **must** be announced as *"was ₹350"*. Read as a bare number it sounds like
  the price.
- Distance, window, and dietary type are never icon-only.
- Filter chips announce active state and count; the sections announce as headings.

**Performance.** Page size 20 · WebP thumbnails at served resolution · skeleton count matched to
viewport · 60 fps scroll target on the mid-tier floor (Phase 1 §3.6).

### Amendment A8 — quantity display policy

Rule R2 says `quantityAvailable` is never trusted from cache. But the *list* renders from a 5-minute
cache, and a card reading **"3 left"** that is actually 0 is a lie that costs a tap, a page load, and
some trust — repeatedly, because burst supply makes it common rather than rare.

**Change to §2.5:** scarcity is **qualitative in cached contexts** and **exact only after a fresh
fetch**.

| Context | Display |
|---|---|
| List / map / search (cached) | *"Only a few left"* below a threshold; otherwise nothing |
| Bag detail (fresh fetch) | Exact count — *"3 left"* |

We keep the urgency signal without asserting a number we cannot stand behind. The exact count appears
exactly where the user is about to act on it, and where we have just revalidated it.

---

## 5b.2 Map view — toggle within `/discover`

**Purpose.** Answer the one question a list cannot: *is this on my way?*

**User goals.** Understand spatial relationships between several options and their route home.

**Components.** Map · clustered **merchant** pins (D-b2) · user-location dot · selected-pin peek card ·
recentre FAB · list toggle · filter chips overlay.

**States.** `mapLoading` · `loaded` · `clustering` · `pinSelected` · `noPinsInViewport` ·
`offline` · `sdkFailed`.

**Empty states.** No pins in the current viewport → non-blocking overlay: *"No bags in this area — zoom
out or switch to list."*

**Error states.**

| Failure | Handling |
|---|---|
| Map SDK fails to initialise | **Automatic fallback to list** with an explanatory note. Never a blank grey rectangle — the single most common map failure presentation, and indistinguishable from a broken app. |
| Offline | Tiles unavailable → prompt to switch to list, which works from cache |

**Validation.** None.

**Accessibility — stated honestly.** A pannable, zoomable map is not meaningfully accessible to a
screen-reader user, and pretending otherwise with pin labels alone is worse than admitting it.
Therefore: **the map is never the only route to anything.** The list view is a complete functional
equivalent, D-b3 makes it the default, and entering map view announces that a list alternative
exists. Pins carry semantic labels; the recentre and toggle controls are fully labelled and ≥ 48 dp.

---

## 5b.3 Search — `/discover/search`

**Purpose.** Intent-driven lookup by shop, food type, category, or locality (D-b4).

**User goals.** Find a specific shop they already trust, or a kind of food.

**Components.** Auto-focused field with clear button · **scope hint** · recent searches (removable) ·
trending categories · grouped results (merchants, then bags) · cancel.

**The scope hint is load-bearing.** *"Search shops, bakeries, food types — bag contents are a
surprise."* Without it, a user searching for a specific dish gets an empty screen and concludes the
marketplace has nothing. One line converts a dead end into a correct mental model of the product.

**States.** `idle` · `typing` · `searching` (debounce 300 ms, min 2 chars) · `results` · `noResults` ·
`error`.

**Empty states.** No recents → trending categories and popular nearby merchants, never a bare field.
No results → *"No matches for 'kaju katli'"* + restatement of scope + category browse suggestions.

**Error states.** Per §C5, with recents still shown so the screen is never wholly unusable.

**Validation.** Trim · min 2, max 60 characters · sanitise before it reaches the query.

**Accessibility.** Result count announced politely on settle (*"7 results"*). Auto-focus announces the
field and its purpose. Each recent-search delete is individually labelled (*"Remove kaju katli from
recent searches"*) — an unlabelled row of X buttons is unusable by screen reader.

---

## 5b.4 Filter sheet — bottom sheet, no route (§4.6)

**Purpose.** Edit the URL facet state (§4.5).

**Components.** Grouped sections — Dietary · Pickup time · Distance · Price · Category · Food type ·
Minimum rating — plus **Reset** and an **Apply button carrying a live result count**.

**The live count on Apply** (*"Show 12 bags"*) prevents the commonest filter dead end: applying a
combination that yields nothing, landing on an empty screen, and having to reverse-engineer which
facet was responsible. A debounced count-only query runs as facets change.

**Dietary group, special handling (D-b5).** Widening away from the user's stored acceptance set shows
a calm, one-line note — *"This will show food outside your usual preference"* — and applies for the
session only. Not a nag, not a confirmation dialog; simply an honest signal, because accidentally
and permanently widening a religious constraint is a harm we can cheaply prevent.

**States.** `idle` · `counting` · `countReady` · `countZero` (Apply still permitted, warned) ·
`applying`.

**Error states.** Count query fails → Apply enabled **without** a count. A broken convenience feature
must not block the primary action.

**Validation.** Price min ≤ max · distance clamped to the allowed set · at least one dietary option
must remain selected.

**Accessibility.** Sheet traps focus and restores it on dismiss. Each group is a heading; options are
checkbox or radio semantics as appropriate. Apply announces its count. Fully operable and scrollable
at `textScaleFactor` 2.0 — a sheet with fixed height is the usual failure here.

---

## 5b.5 Sort sheet — bottom sheet, no route

**Purpose.** Reorder results.

**Components.** Radio list — *Urgency then distance* (default, D-b1) · Distance · Pickup time ·
Price low→high · Discount % · Rating.

**States.** `idle` · `applying`. **Empty / error states.** None. **Validation.** Exactly one.

**Accessibility.** Radio group semantics with the current selection announced as checked; the default
option is labelled as such rather than merely pre-selected.

---

## 5b.6 Location switcher — bottom sheet, no route

**Purpose.** Change the discovery anchor without leaving Discover.

**Components.** *Use current location* (when permitted) · saved locations (authenticated only) ·
recent areas · **Search a new area** → §5a.4.

**States.** `idle` · `detecting` · `detectFailed` · `applying`.

**Empty states.** Anonymous or no saved locations → recents and a prompt to search; never an empty
sheet.

**Error states.** GPS detection fails → inline message, other options remain usable.

**Validation.** Applying a new anchor rewrites `?anchor=` and invalidates the feed.

**Accessibility.** Current anchor announced as checked; each option states its distance from the
current anchor where known.

---

## 5b.7 Category browse — `/discover/category/:categoryId`

**Purpose.** Browse one merchant category with the full facet bar intact.

**Components.** As §5b.1, with the category name as the screen heading and that facet locked.

**States.** As §5b.1, plus `notFound`.

**Error states.** Unknown or withdrawn `categoryId` → **scoped not-found inside the tab** (§4.8) with a
route back to Discover. Realistic rather than hypothetical: the taxonomy is server-driven (§2.3), so a
shared link or stale cache can reference a category that no longer exists.

**Validation.** `categoryId` resolved against cached taxonomy, then the network, before declaring
not-found.

**Accessibility.** Category name is the `header` semantic; announced on entry.

---

## 5b.8 Merchant profile — `/discover/merchant/:merchantId`

**Purpose.** Establish trust, and show everything this merchant currently has.

**User goals.** Decide whether this shop is legitimate; see its bags; know exactly where to go.

**Components.**

| Region | Contents |
|---|---|
| Hero | Storefront photo carousel |
| Identity | Display name · category · rating with count · distance |
| **Trust block** | **FSSAI licence number · licence validity · verified badge** — compliance-required (Phase 1 §3.3), not optional decoration |
| Actions | Save toggle · **Watch toggle** (*"Notify me when they list"* — `BagWatch`, §2.7.2) |
| Location | Address with **landmark and floor/shop number** · **Directions** |
| Info | Operating hours · description |
| Bags | Live bag cards, or §5b.9's empty treatment below |
| Reviews | Summary, recent reviews, link to all |
| **Legal** | Legal entity name · grievance officer contact — Consumer Protection (E-commerce) Rules 2020 |

**States.** `loading` (skeleton) · `loaded` · `loadedNoBags` · `stale` · `offline` · `notFound` ·
`error`. Save and watch toggles are optimistic with rollback (§2.5); tapping either while
unauthenticated triggers the auth wall with `redirect` back to this profile.

**Empty states.** **No live bags → the highest-value empty state in the app.** *"No bags right now"* +
**Watch** as the primary CTA + honest timing education (*"Sweet Crumb usually lists around 8 pm"*).
This converts an empty profile into a subscription, which is precisely the retention loop a
burst-supply marketplace runs on.

**Error states.** Merchant delisted → `notFound` with a route back, not a crash. Photos fail → labelled
placeholder, never a broken-image glyph.

**Validation.** None.

**Accessibility.** Carousel: position announced (*"Photo 2 of 4"*) and **navigable without swipe** —
arrow controls required. Rating announced in full: *"4.3 out of 5, 128 reviews"*, never a bare number.
The FSSAI licence number is announced **digit by digit**, not as a spoken cardinal number — it is an
identifier, and hearing "twelve billion…" makes it unverifiable. Toggle state changes announced
(*"Saved"* / *"Watching"*).

---

## 5b.9 Bag detail — `/discover/bag/:bagId`

**Purpose.** The conversion screen — and the hardest screen in the product. It must create enough
certainty about a deliberately undisclosed product to justify prepayment.

**User goals.** Understand what I'm getting, whether I can eat it, when and where to collect, and
whether it is worth the money.

**Components.**

| Region | Contents |
|---|---|
| Image | Representative image + **explicit disclosure: *"Image is representative. Contents vary daily."*** |
| Identity | Bag title · merchant (→ §5b.8) |
| **Dietary** | Envelope, prominent, with text label — the guaranteed contract (Phase 1 §3.1) |
| Price | Price · struck retail value · discount % |
| **What to expect** | Category hint and description — *"A selection of today's unsold breads, pastries and cookies."* |
| Safety | Allergen notes |
| Scarcity | **Exact remaining count** — fresh fetch (A8) |
| Time | Pickup window, prominent, with countdown when opening or closing soon |
| Place | Landmark · floor/shop · distance · **Directions** |
| Instructions | Pickup instructions · *"bring your own bag"* |
| Social | Merchant rating summary · recent reviews |
| Sticky bar | Quantity stepper (capped, D-b6) · **Reserve for ₹120** |

**The representative-image disclosure is not legal boilerplate to be minimised.** Showing an
appealing photo of food that is not what is in the bag, without saying so, is a misleading commercial
representation — an exposure under consumer-protection rules and, more immediately, the fastest route
to one-star reviews saying *"not what was in the picture."* It sits adjacent to the image, in the
semantic tree, at readable size.

**States.** `loading` · `loaded` · `stale` · `revalidating` (on Reserve tap) · `soldOut` ·
`windowClosed` · `withdrawn` · `notFound` · `error`.

**Error states.**

| Case | Treatment |
|---|---|
| `soldOut` on load | Prominent state; CTA becomes *Notify me* + alternatives at this merchant and nearby |
| `windowClosed` | Same shape, different copy |
| `withdrawn` | *"This bag is no longer available"* + alternatives |
| **Revalidation fails on Reserve tap** (409) | **Domain-specific, never generic** (§C5): *"This bag just went"* + three alternatives + one-tap watch. This is the §3.1 step 8 / §3.2 race, and it is frequent — it deserves authored design, not an error toast. |

**Validation.** Quantity stepper bounded by `min(quantityAvailable, 2)` per D-b6. Reserve performs a
hard availability revalidation per R2 before any navigation to `/checkout`.

**Accessibility.**

- **The dietary envelope is early in the semantic order.** A screen-reader user must not traverse
  price, description, and location to discover whether they are permitted to eat this.
- Struck price announced as *"was ₹350"*.
- Countdown is a **polite** live region announced at meaningful thresholds only — never per second.
- Reserve CTA label includes the amount: *"Reserve for ₹120"*. A button announced only as "Reserve"
  before a payment flow is an unacceptable ambiguity.
- Stepper buttons labelled *"Increase quantity"* / *"Decrease quantity"*, with the value announced on
  change and the cap announced when reached.

---

## 5b.10 Amendment A9 — per-customer purchase cap

**Change.** A per-customer cap of **2 bags per listing** (D-b6), enforced **server-side** and reflected
in the stepper's maximum.

**Why it is a contract requirement, not a UI rule:** a client-side-only cap is trivially bypassed and
the failure is invisible until a merchant complains that one buyer took all eight bags. The Phase 7
contract must expose the remaining allowance per customer per listing so the stepper renders the true
cap rather than guessing, and must reject over-cap holds with a distinguishable error the UI can
explain.

---

## 5b.11 Reviews list — reached from §5b.8

**Purpose.** Depth of social proof for a trust-limited purchase.

**Components.** Rating distribution histogram · tag frequency chips · paginated reviews (rating, tags,
comment, month, verified-purchase marker).

**States.** `loading` · `loaded` · `paginating` · `empty` · `error`.

**Empty states.** New merchant with no reviews → *"No reviews yet — be the first"*, framed neutrally.
An absence of reviews must not read as a negative signal for a merchant we have verified.

**Validation.** None (read-only).

**Accessibility.** The histogram needs a text equivalent (*"5 stars: 82 reviews, 64%"*) — a bar chart
alone is inaccessible. Every review is one merged node; the verified marker is announced.

---

## 5b.12 Amendment A10 — three zero-result states, not one

Phase 2 §2.4 listed a single *"No-supply-in-area state."* Three causally distinct situations were
hiding inside it, and they require **opposite remedies**. Collapsing them is the classic marketplace
empty-state failure: the user is told "nothing here" and given the wrong lever.

| State | Cause | Copy direction | Primary action |
|---|---|---|---|
| **No coverage** | No merchants in this area at all | *"We're not live in Indiranagar yet"* | **Notify me here** + nearest live area with distance and one-tap switch |
| **No supply now** | Merchants exist; none listing at this moment | *"No bags right now in Indiranagar"* + *"Bags usually appear between 7 and 10 pm"* | **Watch merchants who list here** + notify me |
| **Over-filtered** | Supply exists; the facets exclude all of it | *"No bags match your filters"* with the active chips shown | **Clear filters** |

**Notify-me is available to anonymous users** with locality plus device push token — no phone number,
no auth wall. Latent demand by locality is the cheapest and most valuable signal a pre-launch
marketplace can collect, and putting an OTP in front of it is how you collect none of it.

**States.** `idle` · `submitting` · `registered` · `submitError` (retry, input preserved).

**Accessibility.** The state and its reason are announced on entry — a screen-reader user must learn
*why* the screen is empty, not merely that it is. Primary CTA labelled with its effect
(*"Notify me when bags are available in Indiranagar"*).

**Surface-map effect.** Discovery's destination count goes from 10 to 12.

---

## Handed to Phase 6

New design-system requirements from this area: **bag card** (the most-repeated composite in the app) ·
**dietary mark + label** pairing · **struck-price / discount** treatment · **urgency section header** ·
**facet chip** with active state and count · **scarcity cue** (qualitative and exact variants) ·
**countdown text** at three urgency levels · **stale banner** · **cart-hold banner** · **map pin and
cluster** · **rating histogram with text equivalent** · **photo carousel with non-swipe controls** ·
**trust block** (FSSAI, verified) · **three empty-state layouts** · **sticky action bar**.
