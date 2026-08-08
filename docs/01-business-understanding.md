# Phase 1 — Business Understanding, Assumptions & Constraints

Status: **approved** · Date: 2026-07-26

---

## 1. What we are building

An original, India-specific surplus-food marketplace. Businesses list food that would otherwise be
discarded; customers reserve and prepay, then collect during a stated pickup window. Revenue via
transaction commission.

Mechanically this is a **pre-commitment marketplace for perishable inventory with a hard expiry
clock.** That framing, not "food waste app", dictates the engineering:

| Property | Engineering consequence |
|---|---|
| Inventory value → ₹0 at a known timestamp | Time is a first-class domain concept, not a display string |
| Supply discovered late (6pm, not 9am) | Listings arrive in bursts → push-driven, not browse-driven |
| Inventory is single-unit, non-fungible | Overselling is a correctness bug costing customer trust and merchant staff time → atomic server holds, never optimistic UI |
| Customer travels to merchant | Radius, not city, is the unit of relevance → sub-3km discovery |
| Ticket size ₹49–₹299 | Payment rail choice is a P&L decision |

**The company is merchant-side supply density in specific micro-markets. The app is the thin,
extremely reliable interface to it.** Architecture therefore prioritises correctness and trust over
feature surface.

## 2. Illustrative unit economics

Modelled, not measured — stated so the assumptions are auditable.

- Bag price **₹120** (≈⅓ of ₹350 stated retail value — the discount must feel unarguable)
- Commission **20%** → **₹24** gross per order
- Variable cost: UPI/PG platform fee ~₹1.20 · OTP SMS ~₹0.15 · maps/session ~₹0.50 · push ~₹0
- **Contribution ≈ ₹20–22 per order, pre-support**

Three product mandates follow:
1. **UPI is the pre-selected default rail.** Card MDR on a ₹120 order is a material share of contribution.
2. **CAC must stay under ~₹100**, ruling out paid-acquisition-led growth. Therefore in-store merchant QR standees, referral, and share-a-save are **V1 product surface**, not V2 growth hacks.
3. **Support cost is the silent killer.** Every ambiguous state (merchant no-show, wrong bag, missed window) must be self-serve resolvable in-app.

## 3. India-specific realities that change the product

**3.1 A blind surprise bag is not viable.** Dietary identity here is a hard constraint, not a
preference — pure vegetarian, no-egg, Jain, halal. A mystery bag that might contain egg is not a
mild disappointment; it is a religious violation and a churned user. **Dietary type is a
guaranteed, contractual attribute of every listing**, surfaced as a first-class facet. Surprise is
permitted only *within* a dietary envelope.

**3.2 "Leftovers" framing is fatal.** Perceived hygiene risk is materially higher here than in
Western markets. The product must communicate *"made today, unsold at close"* — cooked-at /
best-before timestamps, FSSAI licence badge, real storefront photo. Trust signals are load-bearing
UI, not decoration.

**3.3 Regulatory surface is app-visible.** Three regimes touch screens directly:
- **FSSAI** — merchants must be licensed FBOs; licence number must be displayed; selling past
  *use-by* is prohibited. **A pickup window must close strictly before the food's safe-consumption
  deadline** — a domain validation rule, not a policy document.
- **Consumer Protection (E-commerce) Rules, 2020** — must display seller legal identity, grievance
  officer and response SLA, and clear refund terms. These become required fields on business
  profile, order detail, and Help & Support.
- **GST §9(5), CGST Act** — e-commerce operators are liable for GST on *restaurant service*
  supplied through them (5%, no ITC). Whether pickup-only alters the characterisation needs tax
  counsel. **App-side mitigation safe under either outcome: display one all-inclusive price, and
  have the API carry an itemised tax/fee breakdown object from day one.**

**3.4 Indian addresses are landmark-based.** Pickup-only makes "find the shop" the entire
experience; a map pin alone generates support tickets. Required: storefront photo, landmark line,
floor/shop number, native maps hand-off. Geocoding/places/maps sit behind a provider interface —
V1 on Google for tooling maturity, with an India-native provider (Mappls / Ola Maps) swappable on
cost and address-quality grounds.

**3.5 OTP delivery is regulated and lossy.** TRAI DLT registration of sender headers and templates
is mandatory; unregistered templates are silently dropped and latency is inconsistent. Use SMS
Retriever API for zero-permission autofill, Phone Number Hint API so the user never types their
number, plus voice-OTP and WhatsApp fallback on retry. Auth sits behind our own abstraction, not
welded to one vendor.

**3.6 Device and network floor.** Android-dominant, large installed base of 4GB-RAM mid-tier
devices, patchy connectivity. Budget: <2s cold start on mid-tier, WebP with server-side resizing,
skeletons on every async surface. **Cached listings must re-validate inventory before reservation.**

**3.7 Locale formatting.** `en_IN` grouping (₹1,00,000, not ₹100,000). Trivial now, pervasive to retrofit.

**3.8 Peak surplus is late and category-skewed.** Sweet shops and bakeries clear ~8–10pm,
restaurants ~10–11pm, corporate cafeterias ~3–4pm. Late windows raise a genuine personal-safety
consideration, particularly for women users — verified-storefront cues and share-my-pickup are in scope.

**3.9 Beachhead: bakeries and cafés.** Same-day shelf life, predictable daily surplus, and
"assorted baked goods" is a natural surprise bag. Restaurants have erratic surplus and are the
hardest first sale. *Revised from an original bakery+sweet-shop recommendation:* the
Surprise-Bag-only decision removes the display advantage a mithai shop needs, so sweet shops are a
weaker wedge than they would have been under a hybrid offer model.

## 4. Locked decisions

| Decision | Value |
|---|---|
| V1 scope | **Customer mobile app only.** No merchant app, admin panel, or backend implementation. |
| Offer model | **Surprise Bag only.** Contents undisclosed; dietary envelope guaranteed. Modelled as a sealed type with one variant so `ExactItem` can be added later without touching UI or repositories. |
| Backend | **None yet.** Design API contracts, implement every repository against a swappable in-memory/JSON fake so the app runs and demos end-to-end. |
| Localisation | **English only at launch**, full i18n scaffolding + `en_IN` formatting from commit one. |
| Fulfilment | Pickup-only |
| Payment | Prepaid-only, UPI pre-selected |
| Cart | Single-merchant |
| Auth | Phone + OTP |

## 5. Assumptions register

| # | Assumption | If wrong |
|---|---|---|
| A1 | Pickup-only, no delivery in V1 | Adds logistics domain, live tracking, rider entity — a different product |
| A2 | Prepaid only; no cash-on-pickup | No-show rate rises; merchant value proposition collapses |
| A3 | Single country/currency/timezone (India, INR, IST) | Multi-timezone concerns re-enter the domain layer |
| A4 | Merchant app and admin panel exist separately; V1 defines contracts only | Pickup confirmation has no counterparty (see open items) |
| A5 | Phone+OTP is the only auth method in V1 | Auth abstraction absorbs it; cheap to change |
| A6 | One reservation = one merchant | Cart, hold, and refund logic get substantially harder |
| A7 | Cart holds inventory for a bounded TTL (~8–10 min), auto-released | Overselling or dead inventory |
| A8 | Reservations non-transferable, non-reschedulable in V1; time-boxed cancellation | State machine extension |
| A9 | Pickup verification = dynamic QR **plus** short human-readable fallback code | Pickup fails when merchant scanner or network fails. Fallback is not optional. |
| A10 | Ratings post-pickup only, gated on a collected order | Review integrity, spam |
| A11 | Discovery radius default ~5km, user-adjustable | Tunable config, not architecture |
| A12 | English-first UI, i18n scaffolding from commit one | Retrofitting i18n costs weeks — hence scaffolding regardless |
| A13 | Android-first release, iOS parity at launch, perf tuned to Android mid-tier floor | QA matrix only |
| A14 | No loyalty, wallet, subscription, or gamification in V1 | Deliberately deferred, noted so it isn't mistaken for oversight |
| A15 | Refunds auto-return to source for merchant-side failures, with visible status timeline | Support load and trust damage |
| A16 | We are an intermediary; merchants are sellers of record | Changes tax, liability, invoicing throughout |

## 6. Principal risks

1. **Cold-start liquidity** — an empty map is an uninstall. Zero-supply states must be genuinely
   designed: notify-me-here, expected-availability windows, honest "not live in your area yet".
   Empty states are treated as a feature in Phase 5.
2. **Inventory correctness under concurrency** — highest-severity technical risk. Server-authoritative
   atomic holds; the client never trusts cached counts at reserve time.
3. **Merchant no-show / bag-not-ready** — top predicted support driver. Needs a first-class in-app
   resolution path, not a support email.
4. **Payment ambiguity on UPI app-switch** — pending/timeout/abandoned are common. Payment is a
   reconcilable state machine with server-side verification, never a boolean.
5. **Platform risk** — delivery incumbents could add a surplus product. Defence is pickup-only cost
   structure and merchant relationships, neither app-side.
6. **Food-safety incident** — existential for a food brand. Mitigated by the FSSAI enforcement
   invariant and merchant verification gates.

## 7. Engineering defaults adopted without escalation

Clean Architecture with feature-first modules · Riverpod for state (compile-safe DI, testability,
no `BuildContext` coupling — full justification vs Bloc in Phase 8) · `freezed` immutable models ·
Dio with interceptor-based auth refresh and retry · `go_router` for typed declarative navigation ·
`flutter_secure_storage` over Keystore/Keychain for tokens · provider-abstracted maps, auth,
payments, and analytics so no vendor is welded to the domain.

## 8. Open items

| Item | Needed by |
|---|---|
| Brand name and positioning line | Phase 6 |
| Launch city / micro-market | Phase 9 (copy + mock seed data) |
| Pickup-confirmation counterparty — contract supports both scanner and manual-code paths | Recorded in Phase 7 |
| Flutter/Dart toolchain not on PATH on the dev machine | Blocks Phase 9 only |
| Tax counsel on GST §9(5) characterisation for pickup-only | Not app-blocking (mitigated by R1) |
