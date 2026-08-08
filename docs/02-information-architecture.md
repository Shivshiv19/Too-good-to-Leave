# Phase 2 — Information Architecture

Status: for approval · Depends on: [Phase 1](01-business-understanding.md) · Consumers: Phases 3–9

Locked context: Surprise-Bag-only with guaranteed dietary envelope · pickup-only · prepaid-only ·
single-merchant cart · phone+OTP · no backend (contracts + fakes) · English-only launch with i18n
scaffolding.

---

## 2.1 Domain entity model

### Value objects

| Object | Fields | Decision |
|---|---|---|
| `Money` | `amountInPaise: int`, `currency` | **Integer paise, never `double`.** Floating-point currency is a defect class, not a style preference. Rendered via `en_IN` (₹1,00,000 grouping). |
| `LatLng` | `latitude`, `longitude` | |
| `Address` | `line1`, `line2?`, `floorOrShopNo?`, `landmark`, `locality`, `city`, `state`, `pincode`, `geo` | `landmark` is **required**. Indian addressing is landmark-based and pickup-only makes "find the shop" the whole experience. |
| `PickupWindow` | `startAt`, `endAt` | IST. Derived: `isUpcoming`, `isOpenNow`, `isClosingSoon` (<30 min), `hasClosed`, `timeRemaining` — computed from an injected `Clock`, so testable without waiting for real time. |
| `PriceBreakdown` | `bagSubtotal`, `platformFee`, `taxes: List<TaxLine>`, `discount?`, `total` | Server-computed, client-rendered. Itemised from day one as the GST §9(5) hedge (Phase 1 §3.3). |
| `TaxLine` | `label: String`, `amount: Money` | Labels are **server-supplied strings** so a tax-treatment change never needs an app release. |
| `RatingAggregate` | `average: double`, `count: int`, `histogram: Map<int,int>` | |
| `PickupToken` | `qrPayload` (signed), `fallbackCode` (6-char, unambiguous alphabet), `expiresAt` | Rotating ~60 s. Fallback code is **mandatory** — merchant scanners and networks fail. |

### Enums

| Enum | Values |
|---|---|
| `DietaryEnvelope` | `pureVeg`, `containsEgg`, `nonVeg`, `jain` |
| `MerchantCategory` | `restaurant`, `cafe`, `bakery`, `sweetShop`, `hotel`, `cloudKitchen`, `supermarket`, `groceryStore`, `produceShop`, `corporateCafeteria`, `collegeCanteen`, `other` |
| `BagStatus` | `draft`, `live`, `soldOut`, `windowClosed`, `withdrawnByMerchant` |
| `OrderStatus` | see §2.2 |
| `PaymentStatus` | see §2.2 |
| `PaymentMethod` | `upi`, `card`, `netBanking`, `wallet` |

All enums are **string-backed with a tolerant decoder**: an unknown server value maps to a
designated fallback rather than throwing. A new merchant category must never crash an old client.

### Aggregates

**`Customer`** — `id`, `phone` (E.164), `displayName`, `email?`, `avatarUrl?`,
`dietaryPreference: DietaryEnvelope?`, `createdAt`.

**`Merchant`** — `id`, `legalName`, `displayName`, `category`, `foodTypeTags`,
`fssaiLicenceNumber`, `fssaiLicenceExpiry`, `certifications`, `logoUrl`, `storefrontPhotos`,
`address`, `phone`, `operatingHours`, `description`, `ratingAggregate`, `isVerified`,
`grievanceContact`.

`legalName` and `grievanceContact` satisfy the Consumer Protection (E-commerce) Rules 2020
disclosure duty; `fssaiLicenceNumber` and `fssaiLicenceExpiry` satisfy FSSAI display requirements.
These are compliance-load-bearing fields, not metadata.

**`SurpriseBag`** — modelled as a **sealed `Offer` type with a single variant.** Nothing in the
domain, UI, or data layer may pattern-match on "the only kind of offer"; all consumption goes
through exhaustive switch. Adding `ExactItem` later becomes a compile-error-guided change rather
than a codebase audit.

Fields: `id`, `merchantId`, `title`, `description`, `dietaryEnvelope`, `categoryHint`,
`price: Money`, `statedRetailValue: Money`, `quantityTotal`, `quantityAvailable`, `pickupWindow`,
`safeUntil: DateTime`, `imageUrl`, `allergenNotes?`, `pickupInstructions`, `status`.

Constructor-enforced invariants:
- **I1** `pickupWindow.endAt <= safeUntil` — FSSAI: food may not be sold for collection after its
  safe-consumption deadline. A violating listing is **unconstructable**.
- **I2** `price < statedRetailValue` — the discount claim must be true.
- **I3** `0 <= quantityAvailable <= quantityTotal`
- **I4** `pickupWindow.startAt < pickupWindow.endAt`

**`Cart`** — `customerId`, `merchantId`, `lines`, `holdExpiresAt`, `breakdown`. Single-merchant by
construction: adding a bag from another merchant is an explicit replace-cart decision surfaced to
the user, never a silent merge.

**`Order`** — `id`, `orderCode` (human-readable, e.g. `SV-7K2M`), `customerId`,
`merchantSnapshot`, `lines` (each carrying a `bagSnapshot`), `breakdown`, `pickupWindow`, `status`,
`payment`, `pickupToken?`, `collectedAt?`, `cancelledAt?`, `cancellationReason?`, `createdAt`.

**Snapshot principle:** an order embeds immutable copies of merchant, bag, and price as at purchase.
Orders are receipts. If a merchant renames, reprices, or deletes a listing, a six-month-old order
must still render exactly what was bought. Referencing live entities from an order is both a
correctness and a legal defect.

**`Payment`** — `id`, `orderId`, `method`, `gatewayRef`, `amount`, `status`, `attempts`, `refund?`.

**`Refund`** — `id`, `amount`, `reason`, `status`, `initiatedAt`, `expectedByAt`. Hangs off
`Payment`, not `Order`: money movement is the payment's concern, and one order may have multiple
attempts with independent refund needs.

**`Review`** — `id`, `orderId` (**required** — this is what makes a review authentic and
un-spammable), `customerId`, `merchantId`, `rating: 1..5`, `tags`, `comment?`, `createdAt`. One
review per collected order.

**Supporting** — `SavedMerchant`, `BagWatch`, `SearchLocation`, `AppNotification`,
`NotificationPreference`, `OrderIssue`, `DeviceSession`.

`DeviceSession` (`deviceId`, `fcmToken`, `refreshTokenId`, `lastSeenAt`) exists from V1 so token
refresh and push targeting have a subject, and "log out everywhere" is possible later.

---

## 2.2 State machines

### `OrderStatus`

```
                  ┌────────── paymentFailed ◄──┐ capture fails
                  ▼               │ retry      │
[checkout] ─► pendingPayment ─────┘            │
                  │ payment captured           │
                  ▼                            │
              confirmed ◄──────────────────────┘
                  │
    ┌─────────────┼──────────────┬────────────────────┐
    │ window      │ customer     │ merchant           │ window closed,
    │ opens       │ cancels      │ withdraws          │ uncollected
    ▼             ▼              ▼                    ▼
readyForPickup  cancelledBy   cancelledBy      expiredUncollected
    │           Customer      Merchant
    │ QR or fallback code verified
    ▼
collected
```

Terminal: `collected`, `expiredUncollected`, `cancelledByCustomer`, `cancelledByMerchant`.

**Refund progress is not an order status** — read from `order.payment.refund.status`. One concept,
one place.

`readyForPickup` is persisted rather than purely derived, because the merchant side may mark a bag
ready before the window opens, and notification scheduling needs a durable trigger.

### `PaymentStatus`

```
created ─► pending ─► pendingVerification ─► captured   (terminal success)
                            ├─► failed              (retryable)
                            └─► cancelled           (user abandoned)

captured ─► refundInitiated ─► refunded | refundFailed
```

**`pendingVerification` is the most important state in the system.** Indian UPI intent flows
app-switch to GPay/PhonePe/Paytm and frequently return an indeterminate result — the user may have
paid, abandoned, or timed out, and the client cannot know which. On return from app-switch the
client enters `pendingVerification` and polls a **server-side verification endpoint**. A
client-reported success never confirms an order.

### `BagStatus`

```
draft ─► live ─┬─► soldOut
               ├─► windowClosed          (automatic at pickupWindow.endAt)
               └─► withdrawnByMerchant
```

### `PickupWindow` derived state

`upcoming` → `openNow` → `closingSoon` (<30 min) → `closed`. Derived, never stored.

---

## 2.3 Content taxonomy

### Server-driven, not compiled in

The brief requires the architecture stay "generic enough to support additional business types in the
future." A hardcoded category list makes every new merchant type an app-store release, gated in
practice on 2–6 weeks of user update adoption.

**Decision:** categories, food-type tags, filter definitions, and their display metadata (label,
icon key, sort order) come from `GET /config/taxonomy`, cached persistently with ETag revalidation,
shipped with a bundled fallback so a cold first launch on a dead network still works. Client enums
exist only for values with *behavioural* meaning.

`DietaryEnvelope` is the deliberate exception — compiled in, because each value carries domain logic
and legal/religious weight. It must not be silently extensible by a server change.

### Facet dimensions

| Facet | Type | Notes |
|---|---|---|
| Dietary envelope | single-select, **sticky** | Set at onboarding, applied globally by default |
| Pickup time | single-select | Available now · Later today · Tomorrow |
| Distance | single-select | 1 / 3 / 5 / 10 km |
| Price band | range | |
| Merchant category | multi-select | server-driven |
| Food type | multi-select | server-driven |
| Minimum rating | single-select | |
| Sort | single-select | Distance · Pickup time · Price · Discount % · Rating |

**Sticky dietary preference** is a core IA decision. A pure-vegetarian or Jain user must never
re-apply that filter — it is an identity attribute, not a browsing whim. Set at onboarding,
persisted, applied to every query by default, always *visibly* indicated so the user knows results
are narrowed, and overridable per session.

**Halal is a merchant certification, not a `DietaryEnvelope` value.** It is orthogonal to the
veg/non-veg axis — a halal-certified merchant can sell a pure-veg bag. Collapsing the axes would be
both a modelling error and a cultural one.

---

## 2.4 App surface map

| Area | Destinations |
|---|---|
| **A. Onboarding & Auth** (9) | Splash · Onboarding carousel · Phone entry · OTP verify · Profile setup · Dietary preference setup · Location permission primer · Location detect/manual picker · Notification permission primer |
| **B. Discovery** (10) | Discover (list) · Map view · Search · Filter sheet · Sort sheet · Location switcher · Category browse · Merchant profile · Bag detail · No-supply-in-area state |
| **C. Reserve & Pay** (7) | Cart · Checkout · Payment method sheet · UPI app chooser · Payment processing · Payment failed/retry · Reservation confirmed |
| **D. Orders & Pickup** (7) | Active orders · **Pickup screen** (QR + fallback code + countdown + directions) · Order detail · Order history · Cancel order · Report an issue · Refund status |
| **E. Engagement** (5) | Notification centre · Saved merchants · Bag watchlist · Rate & review · Review submitted |
| **F. Account** (11) | Profile · Edit profile · Saved locations · Notification settings · App settings (theme/language) · Help & support · FAQ topic · Contact us · Legal (T&C, Privacy, Refund policy, Grievance officer) · About · Delete account · Logout |
| **Global** | No internet · Force update · Maintenance · Session expired · Generic error |

≈48 destinations.

### Primary navigation

Bottom navigation, four tabs: **Discover · Orders · Saved · Account**

- **Orders earns a top-level tab** — unusual for a commerce app, correct here. In a delivery app the
  user waits passively; in a pickup app they must physically travel to a place inside a time window.
  The Pickup screen is the highest-stakes, most time-critical surface in the product and cannot be
  buried two levels deep under Account.
- **Map is a toggle inside Discover, not a tab** — list and map are two renderings of one filtered
  dataset. Splitting them across tabs fragments filter and location state and forces the user to
  re-declare intent when switching view. One query, two presentations.
- **Cart is a flow, not a tab** — carts are single-merchant with a short server-side TTL hold. A
  persistent cart tab implies durable, cross-merchant, browse-and-return semantics we deliberately
  do not have. Cart is a modal flow off Bag Detail, with the active hold surfaced as a countdown
  banner so it can never be silently lost.
- **Saved over Search as a tab** — search is intent-driven and belongs in Discover's app bar.
  Re-engagement with a small set of known nearby merchants is the retention loop worth a tab, given
  supply arrives in late-evening bursts.

---

## 2.5 Data ownership and cache authority

The artifact that prevents the overselling class of bug.

| Entity / field | Authority | Client cache | TTL | Revalidate before write |
|---|---|---|---|---|
| Taxonomy & remote config | Server | Persistent + bundled fallback | 24 h, ETag | n/a |
| Merchant profile | Server | Yes | 1 h | No |
| Bag listings (discovery feed) | Server | Yes — enables offline browse | 5 min, display "as of HH:MM" | — |
| **`bag.quantityAvailable`** | **Server only** | **Never trusted** | 0 | **Yes — at add-to-cart *and* again at checkout** |
| Cart hold | **Server** | Mirror only | until `holdExpiresAt` | Yes |
| **`PriceBreakdown`** | **Server only** | Mirror for active session | per checkout session | **Yes — never computed client-side** |
| Order immutable fields | Server (snapshot) | Persistent, indefinite | ∞ | No |
| `order.status` | Server | Yes | push-invalidated; 30 s poll while Pickup screen foregrounded | — |
| **`payment.status`** | **Server only** | **Never** | 0 | **Yes — server-side verification** |
| `PickupToken.qrPayload` | Server, short-lived | Briefly | rotate ~60 s | — |
| Saved merchants / watchlist | Server, offline-queued | Yes | optimistic + rollback | No |
| Reviews | Server | Yes | 1 h | No |
| Customer profile | Server | Yes | invalidate on change | No |
| Notification preferences | Server | Yes | optimistic + rollback | No |
| Auth tokens | Server-issued | Secure storage only, never the cache DB | access ~15 min, refresh ~30 d | — |

### Three non-negotiable rules

- **R1 — Money is never computed on the client.** The client renders a server-provided
  `PriceBreakdown` and nothing else. No client-side summing of lines, no client-side tax or fee
  arithmetic. This is precisely what makes the unresolved GST §9(5) question harmless to the app.
- **R2 — Availability is never read from cache at a mutation boundary.** Cached listings are for
  *browsing*. Add-to-cart and checkout each perform a hard server revalidation. Showing "2 left"
  from a 5-minute-old cache and then failing at payment is worse than showing nothing.
- **R3 — Payment outcome is never determined by a client callback.** Gateway and UPI app callbacks
  are hints that trigger verification, never facts.

**Offline posture:** discovery and order history browse offline; every mutation is blocked offline
**except** saved-merchant and watchlist toggles, which queue and replay. Reserving a bag offline is
not a feature — it is a promise we cannot keep.

---

## 2.6 Notification and deep-link inventory

Supply arrives in late-evening bursts, so push is the core product loop rather than an ancillary
feature. Every type is defined here so the router is designed around them rather than retrofitted.

| Type | Trigger | Destination route | Priority |
|---|---|---|---|
| `newBagsNearby` | Supply burst within radius, dietary-filtered | `/discover?anchor={locId}` | High, rate-limited |
| `watchedMerchantListed` | Watched merchant goes live | `/merchant/{id}` | High |
| `pickupWindowOpening` | 30 min before `startAt` | `/orders/{id}/pickup` | High |
| `pickupClosingSoon` | 45 min before `endAt`, uncollected | `/orders/{id}/pickup` | **Max** |
| `orderConfirmed` | Payment captured | `/orders/{id}` | Default |
| `paymentFailed` | Capture failed | `/checkout/retry?orderId={id}` | High |
| `merchantCancelled` | Merchant withdrew the bag | `/orders/{id}` | **Max** |
| `refundInitiated` / `refundCompleted` | Refund state change | `/orders/{id}/refund` | Default |
| `rateYourPickup` | 1 h after `collected` | `/orders/{id}/review` | Low |

Constraints this imposes on Phase 4:

1. Every route must resolve from a **cold start** with no in-memory state.
2. Auth-guarded routes must capture the intended destination and restore it after login — a push
   tapped by a logged-out user must not dead-end on the home screen.
3. Declarative typed routes, with deep-link parity across custom scheme, Android App Links, and iOS
   Universal Links.
4. `notificationPreference` toggles map 1:1 onto these types, so a user can mute `newBagsNearby`
   without muting `pickupClosingSoon`. Muting a transactional alert the user has money riding on
   would be a dark pattern in reverse.

---

## 2.7 IA decisions forced by the Phase 1 choices

Seven places where the brief's feature list needed reinterpretation — flagged rather than silently
resolved.

1. **"Saved addresses" → Saved *locations*.** Pickup-only means there is no delivery address. The
   user needs named discovery anchors (Home, Work, Mum's place) to search around. Same affordance,
   different semantics; modelling it as a delivery address would propagate a wrong concept into
   checkout.
2. **"Favorite items" → Bag watchlist.** With surprise-bags-only, a bag is an ephemeral daily
   instance — today's bag does not exist tomorrow, so favouriting one is meaningless. The real
   intent is *"tell me when this merchant lists again"* → `BagWatch(merchantId, notifyOnList)`. A
   direct consequence of the Surprise-Bag-only decision.
3. **User-facing "Reservation" == domain `Order`.** The brief's reservation language is UX
   vocabulary. A separate `Reservation` aggregate alongside `Order` would create two sources of
   truth for one fact. One aggregate, two vocabularies, mapping documented so nobody reintroduces it.
4. **Refund belongs to `Payment`, not `Order`.**
5. **Halal is a merchant certification, not a dietary envelope value.**
6. **Categories are server-driven**, not compiled in.
7. **Cart is a flow, not a destination.**

---

## Open items carried forward

- Brand name and positioning line — needed by Phase 6.
- Launch city / micro-market — sharpens copy and mock seed data; needed by Phase 9.
- Pickup-confirmation counterparty — contract will support both scanner and manual-code paths;
  dependency to be recorded in Phase 7.
- Flutter/Dart toolchain not on PATH — blocks Phase 9 only.
