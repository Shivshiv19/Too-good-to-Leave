# Phase 7 — API Contracts

Status: for approval · Depends on: Phases 1–6 (incl. A1–A22) · Consumers: Phases 8, 9

These contracts are the source of truth for **both** the V1 fake repositories and any future backend
(Phase 1 locked decision: no backend yet). They are written as though a backend team will implement
them, because one eventually will.

> Amendments: **A23** (§7.2.4) · **A24** (§7.2.3).

---

## 7.1 Conventions

### 7.1.1 Versioning

Path-prefixed: `/v1/`. **Additive changes only** within a version — new fields, new enum values, new
endpoints. Breaking changes mint `/v2/`. A client that must be retired is handled by
`force_update_required` (§7.1.5), not by silently breaking `/v1/`.

### 7.1.2 Response shape

**Bare resource bodies for single resources; a wrapper only for collections**, which genuinely need
pagination metadata.

```json
GET /v1/orders/ord_8kd2        →  { "id": "ord_8kd2", "status": "confirmed", ... }
GET /v1/orders                 →  { "items": [ ... ], "nextCursor": "c_9fj2" }
```

A universal `{data: …}` envelope was rejected: HTTP already carries status, and an extra indirection
layer on every response buys nothing while making every `freezed` model one level deeper than the
domain it represents.

### 7.1.3 Primitive representations

| Concept | Wire format | Why |
|---|---|---|
| **Money** | `{"amountInPaise": 12000, "currency": "INR"}` | Integer paise (§2.1). Never a float — floating-point currency is a defect class. Never a pre-formatted string — the client owns `en_IN` presentation. |
| **Timestamp** | ISO 8601 with **explicit offset** — `2026-07-26T20:00:00+05:30` | Pickup windows are wall-clock-meaningful to a human standing outside a shop. Epoch integers are unreadable in fixtures and logs; naive local times are ambiguous. |
| **Duration** | Integer seconds, suffixed field name (`expiresInSeconds`) | Unit in the name prevents the classic ms/s confusion |
| **IDs** | Prefixed opaque strings — `ord_`, `bag_`, `mer_`, `pay_` | Type-evident in logs, and prevents an ID of the wrong type being accepted |
| **Enums** | Lowercase snake_case strings | Never integers — an integer enum is unreadable and reorderable |

### 7.1.4 Enum tolerance — a contract obligation on both sides

**Servers MAY add enum values without a version bump. Clients MUST tolerate unknown values** by mapping
them to a designated fallback (§2.1).

This is what makes the server-driven taxonomy (§2.3) workable: a new merchant category must never crash
an old client. It is stated as a mutual obligation because a tolerant client and an additive-only server
are each useless without the other.

### 7.1.5 Errors

```json
{
  "error": {
    "code": "bag_sold_out",
    "message": "Bag bag_7k2m has 0 remaining",
    "correlationId": "req_a91f3c",
    "details": { "alternativeBagIds": ["bag_9x1p", "bag_2m4k"] }
  }
}
```

**`code` is the contract; `message` is for developers and is never displayed** (§C5). The client maps
every code to authored copy. `correlationId` surfaces only in an expandable *Details* affordance for
support.

**Domain error codes** — enumerated because §C5 requires domain-specific copy rather than a generic
409 handler:

| Code | HTTP | `details` | Screen |
|---|---|---|---|
| `bag_sold_out` | 409 | `alternativeBagIds[]` | §5b.9, §5c.1 |
| `bag_withdrawn` | 409 | `alternativeBagIds[]` | §5b.9 |
| `bag_window_closed` | 409 | — | §5b.9 |
| `purchase_cap_exceeded` | 409 | `remainingAllowance` | A9 |
| `hold_expired` | 409 | `bagId` (for one-tap re-reserve) | §5c.1 |
| `hold_conflict_other_merchant` | 409 | `existingMerchantName` | A6 |
| `quote_stale` | 409 | `currentBreakdown` | A11 |
| `payment_declined` / `_cancelled` / `_timeout` | 402 | **`chargeState`** | A13 |
| `cancellation_window_passed` | 409 | `cutoffAt` | A15 |
| `review_already_exists` | 409 | `reviewId` | §5e.3 |
| `order_not_reviewable` | 409 | `currentStatus` | §5e.3 |
| `notification_not_dismissible` | 409 | `orderId` | §5e.1 |
| `otp_invalid` | 401 | `attemptsRemaining` | §5a.7 |
| `otp_expired` | 401 | — | §5a.7 |
| `otp_attempts_exhausted` | 429 | `retryAfterSeconds` | §5a.7 |
| `otp_rate_limited` | 429 | `retryAfterSeconds` | §5a.6 |
| `otp_channel_unavailable` | 503 | `channelsAvailable[]` | §5a.6 |
| `account_deletion_blocked` | 409 | `blockers[]` | A20 |
| `session_expired` | 401 | — | §5a.11 |
| `force_update_required` | **426** | `storeUrl`, `reason` | §5a.9 |
| `maintenance` | 503 | `etaAt?` | §5a.10 |

### 7.1.6 Idempotency

An `Idempotency-Key` header (client-generated UUID) is **required** on every state-changing request that
could be retried ambiguously. The server stores key → response for 24 h and replays the stored response
on a repeat.

| Endpoint | Why it is mandatory |
|---|---|
| `POST /auth/otp/verify` | **§5a.7** — a network failure mid-verify may already have consumed the code. Retrying the same code must succeed rather than reporting it invalid. |
| `POST /orders` | A duplicate order is a duplicate charge |
| `POST /payments/*/verify` | Polled repeatedly by design (§5c.6) |
| `POST /orders/*/cancel` | A double cancel must not double-refund |
| `POST /orders/*/review` | |
| `POST /orders/*/issues` | |
| `POST /me/delete` | |

### 7.1.7 Pagination

**Cursor-based, never offset.** The bag feed mutates constantly — burst supply, sell-outs — and offset
pagination under mutation duplicates and skips items. `{items, nextCursor}`; `nextCursor: null` means the
end. Default `limit` 20, max 50.

### 7.1.8 Caching

`ETag` + `If-None-Match` → `304` on: `/config`, `/config/taxonomy`, `/legal/*`, `/help/*`,
`/merchants/{id}`. `Cache-Control: no-store` on `/bags/{id}`, `/payments/*`, `/orders/*/pickup-token` —
the endpoints where R2 and R3 forbid cached reads.

### 7.1.9 Rate limiting

`429` with `Retry-After`. Keyed by device token (§7.2.4) for public endpoints and by customer for
authenticated ones. OTP request is separately and aggressively limited per phone number.

---

## 7.2 Authentication

### 7.2.1 OTP request

`POST /v1/auth/otp/request` → `{ requestId, expiresInSeconds, resendAfterSeconds, channelsAvailable }`

`channelsAvailable` drives §5a.7's escalation ladder: the client offers WhatsApp and voice **only when
the server says they are available**, rather than advertising a channel that will silently fail. Directly
serves the TRAI DLT reality (Phase 1 §3.5).

### 7.2.2 OTP verify

`POST /v1/auth/otp/verify` (idempotent) `{ requestId, code, deviceId, deviceToken? }`
→ `{ accessToken, refreshToken, expiresInSeconds, customer, isNewCustomer, migratedFromDevice }`

`deviceToken` is what carries anonymous state onto the account (A23).

### 7.2.3 Amendment A24 — refresh token rotation with reuse detection

**Finding.** §2.5 specified access ~15 min, refresh ~30 d, but said nothing about rotation. A long-lived
static refresh token in an app holding prepaid orders is a standing account-takeover primitive: exfiltrate
it once and you have thirty days of access.

**Change.**

- `POST /v1/auth/token/refresh` issues **a new refresh token and invalidates the presented one** —
  single-use rotation.
- **Reuse detection:** presenting an already-consumed refresh token revokes the **entire token family**
  and returns `session_expired`. A replayed token means either a race or a theft, and the safe response
  to both is the same.
- Rotation is invisible to the user (§3.2 requires silent refresh). Family revocation surfaces as
  §5a.11, which is why that screen leads with *"Your orders are safe."*
- Refresh tokens are bound to `deviceId`; `DeviceSession` (§2.1) is the revocation unit, enabling a
  future "log out everywhere".

**Client obligation:** refresh is **serialised**. Concurrent 401s must queue behind a single refresh, not
fire several — parallel refreshes would trip reuse detection and log the user out. This is a Phase 8
interceptor requirement.

### 7.2.4 Amendment A23 — anonymous device token and state migration

**Finding.** A4 permits anonymous discovery and requires that dietary preference and search location
*"persist locally, then migrate to the account on signup"* — but no mechanism was ever specified. A18 and
A10's anonymous notify-me widened the need: an unauthenticated user can now express dietary constraints,
save a search location, and register locality demand, all before an account exists.

Without a server-side anonymous identity there is also no way to rate-limit public endpoints or attribute
notify-me demand signals — which A10 called *"the cheapest and most valuable signal a pre-launch
marketplace can collect."*

**Change.**

- `POST /v1/auth/device` `{ platform, appVersion, deviceId }` → `{ deviceToken }`, issued on **first
  launch**, before onboarding. Long-lived, no personal data.
- Public endpoints accept `deviceToken`; it is the rate-limit and attribution key.
- Anonymous state — dietary acceptance set, search locations, notify-me registrations, push token — is
  stored against the device token.
- `POST /auth/otp/verify` accepts `deviceToken` and **merges** that state into the new or existing
  account, returning `migratedFromDevice`. Conflicts resolve account-wins for an existing account,
  device-wins for a new one.

**Effect on §5a.1:** Splash gains a bootstrap step — obtain or read the device token — which must
degrade gracefully offline: the app proceeds with local-only anonymous state and registers the device on
first connectivity.

### 7.2.5 Session endpoints

| Endpoint | Notes |
|---|---|
| `POST /v1/auth/logout` | Revokes the refresh family for this device. Client clears **all** local user data (§5f.12). |
| `PUT /v1/me/device` | Registers or updates `fcmToken` on the `DeviceSession` |

---

## 7.3 Config and policy

### `GET /v1/config`

```json
{
  "minSupportedAppVersion": "1.0.0",
  "maintenance": { "active": false, "etaAt": null },
  "featureFlags": { ... },
  "policyValues": {
    "cancellationCutoffMinutesBeforeWindow": 60,
    "noShowRefundPolicy": "none",
    "refundSlaWorkingDays": { "min": 3, "max": 7 },
    "grievanceSlaHours": 48,
    "purchaseCapPerListing": 2,
    "holdTtlSeconds": 540
  },
  "taxonomyEtag": "\"tx_44f1\""
}
```

**`policyValues` is A19.** Every surface displaying a policy — the checkout terms block (§5c.2), the
cancel dialog (§5d.5), and the rendered legal documents (§5f.9) — reads these values. No policy number is
authored twice, so the three copies cannot diverge into an unfair-terms exposure.

`purchaseCapPerListing` and `holdTtlSeconds` live here too, so tuning either is a config change rather
than a release.

### `GET /v1/config/taxonomy` (ETag)

Categories, food-type tags, filter definitions, and display metadata (§2.3). Bundled fallback ships with
the app for a cold first launch on a dead network.

---

## 7.4 Discovery

### `GET /v1/bags`

| Parameter | Notes |
|---|---|
| `lat`, `lng`, `radiusKm` | |
| **`acceptedEnvelopes`** | **Comma-separated set** — `pureVeg,jain`. **A7**: a customer has an acceptance *set*, not a single envelope. A scalar parameter here is what would have silently hidden Jain bags from pure-vegetarian users. |
| `categories`, `foodTypes` | Multi-select, taxonomy-driven |
| `priceMinPaise`, `priceMaxPaise`, `minRating`, `pickupWindow` | |
| `sort` | `urgencyThenDistance` (default) · `distance` · `pickupTime` · `priceAsc` · `discountDesc` · `rating` |
| `cursor`, `limit` | |

Response items carry:

```json
{
  "id": "bag_7k2m",
  "merchant": { "id": "mer_31", "displayName": "Sweet Crumb", "category": "bakery", "rating": {...} },
  "title": "Bakery Surprise Bag",
  "dietaryEnvelope": "pureVeg",
  "price": { "amountInPaise": 12000, "currency": "INR" },
  "statedRetailValue": { "amountInPaise": 35000, "currency": "INR" },
  "discountPercent": 65,
  "pickupWindow": { "startAt": "...+05:30", "endAt": "...+05:30" },
  "distanceMetres": 1200,
  "scarcity": "few",
  "imageUrl": "..."
}
```

**`scarcity` is an enum (`few` | `none`), not a count — this is A8 enforced in the contract.** The list
endpoint *cannot* return an exact quantity, so a cached card is structurally incapable of asserting
"3 left" and being wrong. Enforcing a UI rule in the schema is more durable than trusting every call site
to remember it.

### `GET /v1/bags/{bagId}` — `no-store`

Full bag, plus the two fields that only a fresh read may carry:

- **`quantityAvailable`** — exact (A8)
- **`remainingAllowanceForCustomer`** — A9, so the stepper renders the true cap rather than guessing

### `GET /v1/coverage?lat&lng`

```json
{ "status": "noSupplyNow", "nearestLiveArea": { "name": "Koramangala", "distanceMetres": 4100, "anchor": {...} },
  "typicalWindowStart": "19:00", "merchantCountInArea": 12 }
```

**This endpoint exists because the client cannot distinguish A10's three states.** An empty bag list is
identical on the wire whether there are no merchants at all, merchants that are not currently listing, or
merchants excluded by the user's facets. Only the server knows which. Without this signal the client
would have to guess, and A10's whole point is that the three states demand *opposite* remedies.

`status` ∈ `live` · `noSupplyNow` · `noCoverage`. Over-filtered is determined client-side, since the
client owns the facets.

### Remaining discovery

| Endpoint | Notes |
|---|---|
| `GET /v1/merchants/{id}` (ETag) | Profile · FSSAI · legal block · live bags · **`typicalListingTime`** (§5b.8 empty state) |
| `GET /v1/merchants/{id}/reviews` | Cursor-paginated, plus histogram aggregate |
| `GET /v1/search?q&lat&lng` | Merchants · categories · food types · localities. **Bag contents are not indexed** (D-b4). |
| `POST /v1/coverage/notify` | `{locality, anchor, deviceToken}` — **accepts anonymous** (A10) |

---

## 7.5 Cart, checkout, payment

The area where A2, A3, A11, A13, R1, R2, and R3 all land.

| Endpoint | Contract |
|---|---|
| `POST /v1/holds` (idem) | `{bagId, quantity}` → `{holdId, expiresAt, breakdown}`. **Revalidates availability** (R2) and enforces the cap (A9). |
| **`POST /v1/checkout/quote`** | `{holdId, quantity}` → `{breakdown}`. **A11** — repeatable, **no side effects on the hold**. This is the endpoint that makes R1 practical: the client asks rather than computes. |
| `PATCH /v1/holds/{holdId}` | `{quantity}` → adjusted hold + fresh breakdown |
| `DELETE /v1/holds/{holdId}` | Explicit release |
| `POST /v1/orders` (idem) | `{holdId, paymentMethod, upiApp?}` → `{order, payment: {id, gatewayPayload}}`. **A2: creating the order freezes the hold — it cannot expire while payment is `pending` or `pendingVerification`.** |
| `POST /v1/payments/{id}/verify` (idem) | → `{status, chargeState, order?}`. **R3** — the only authority on payment outcome. |
| `GET /v1/payments/{id}` | `no-store` poll target for §5c.6 |
| **`GET /v1/orders/unresolved`** | → `{orderId, paymentId, status}` or `204`. **A3** — Splash calls this to detect a payment in flight after a kill mid-app-switch. |

**`chargeState` (A13)** ∈ `notCharged` · `charged` · `uncertain`. The client renders one of two authored
variants and **never infers**. Returning `uncertain` honestly is required — a server that guesses
`notCharged` transfers the lie to the user.

`GET /v1/orders/unresolved` is small and load-bearing: without it, a user who kills the app during a UPI
app-switch has a debit and no order, with nothing in the client able to find it.

---

## 7.6 Orders and pickup

| Endpoint | Contract |
|---|---|
| `GET /v1/orders?status=active\|past` | Cursor-paginated |
| `GET /v1/orders/{id}` | Full snapshot (§2.1) — merchant, bag, price, all immutable |
| **`GET /v1/orders/{id}/pickup-token`** | **A1, three layers** (below) |
| **`GET /v1/orders/{id}/cancellation-eligibility`** | **A15** — `{eligible, cutoffAt, refundOutcome, refundAmount}`. The client renders; it never computes eligibility. |
| `POST /v1/orders/{id}/cancel` (idem) | `{reason?}` |
| `GET /v1/orders/{id}/refund` | Timeline with per-step timestamps and **`expectedByAt`** — §5d.4 forbids a step without a date |
| `POST /v1/orders/{id}/issues` (idem) | `{type, description, attachmentIds[]}`. **A16**: `type: "food_safety"` routes to the escalation class with its own SLA. |
| `POST /v1/attachments` | Presigned upload → `attachmentId`. **EXIF stripped server-side as defence in depth**, in addition to client-side stripping (§5d.6). |
| `POST /v1/orders/{id}/review` (idem) | `{rating, tags[], comment?, alsoCreateIssue?}` — **the §5e.3 escalation bridge in one round-trip**, so a low rating and a food-safety report cannot half-succeed. |

### Pickup token — A1

```json
{
  "rotatingPayload": "...",           "rotationExpiresAt": "...+05:30",
  "offlineToken": "...",              "offlineTokenValidUntil": "...+05:30",
  "fallbackCode": "7K2M9X"
}
```

`offlineToken` is valid for the **entire pickup window** and is fetched and cached at order confirmation,
not at the shop. That ordering is the whole point of A1: the device must already hold a valid token before
it reaches a basement counter with no signal.

`fallbackCode` uses an alphabet excluding `0/O`, `1/I/L` (§2.1), because it is transcribed aloud by a
stranger.

---

## 7.7 Engagement and account

| Endpoint | Notes |
|---|---|
| `GET /v1/notifications` | Cursor-paginated with `unread` and `class` (`transactional` \| `discovery` \| `prompt`) |
| `POST /v1/notifications/read-all` | |
| `DELETE /v1/notifications/{id}` | `409 notification_not_dismissible` while the order is live (§5e.1) |
| `GET /v1/saved` | Merchants with **live availability state** — the whole value of the list (§5e.2) |
| **`PUT /v1/saved/{merchantId}`** | `{watching: bool}`. **A17** — one resource; watching implies saving. |
| `DELETE /v1/saved/{merchantId}` | Clears the watch too |
| `GET` / `PATCH /v1/me` | Phone is **read-only** (§5f.2) |
| `GET/POST/PATCH/DELETE /v1/me/locations` | Max 10 |
| `GET` / `PUT /v1/me/notification-preferences` | **Transactional types are read-only; a PUT attempting to mute one is rejected** (§5f.4). Enforced server-side so a modified client cannot silence an alert the user has money riding on. |
| **`GET /v1/me/deletion-eligibility`** | **A20** — `{eligible, blockers[]}` where a blocker is `activeOrder` or `pendingRefund`, each with its `orderId` |
| `POST /v1/me/delete` (idem) | Requires a **fresh OTP verification** (§5f.11) → `{reactivateBefore}`. 30-day soft delete; sign-in within the window reactivates. |
| `GET /v1/legal/{docId}` (public, ETag) | **Rendered against `policyValues`** (A19) |
| `GET /v1/help/topics`, `/topics/{id}` (ETag) | Restricted markdown subset — **never arbitrary HTML** (§5f.7) |
| `POST /v1/support/tickets` | |

---

## 7.8 Push payload contract

```json
{ "type": "pickupClosingSoon", "title": "...", "body": "...",
  "route": "/orders/ord_8kd2/pickup", "orderId": "ord_8kd2",
  "class": "transactional", "collapseKey": "order_ord_8kd2" }
```

`type` ∈ the §2.6 inventory. `route` **must be resolvable from a cold start** (§4.8) and is validated
against the route table before navigation (§4.3 — an unvalidated route from a remote payload is an
open-redirect primitive). `collapseKey` prevents a stack of notifications for one order.

### A6 — a server obligation, recorded not solved

**Notification fan-out must be quantity-aware.** Notifying 500 users about 3 bags manufactures 497 bad
experiences and trains users to ignore push — which would break the channel the entire supply loop
depends on. The client handles the resulting race gracefully (§5b.9's authored 409 copy); only the server
can prevent it. Recorded here as an explicit backend requirement so it is not lost.

---

## 7.9 The inverse contract — what the client must never do

Restated as obligations, because these are the rules a well-meaning future contributor will break:

| Rule | Client obligation |
|---|---|
| **R1** | Never compute, sum, or adjust a monetary value. Render `PriceBreakdown` as received. Quantity change → `/checkout/quote`. |
| **R2** | Never read `quantityAvailable` from cache at a mutation boundary. `POST /holds` and `POST /orders` each revalidate. |
| **R3** | Never treat a gateway or UPI callback as an outcome. Only `/payments/{id}/verify` decides. |
| **A13** | Never infer `chargeState`. |
| **A15** | Never compute cancellation eligibility or refund outcome. |
| **A24** | Never issue concurrent refreshes — serialise behind one in-flight call. |
| §4.3 | Never navigate to a route from a remote payload without validating it against the route table. |

---

## 7.10 The mock layer

Per the Phase 1 locked decision, every repository has a fake implementation behind the same abstract
interface, swapped at the composition root.

### The fakes must be adversarial, not convenient

A fake that always succeeds instantly means **every error state in Phases 5a–5f ships untested**, and the
app develops habits — trusting cached counts, computing totals locally — that break the first time it
meets a real backend. So the mock layer faithfully models server *authority*, not just server *data*:

| Behaviour | Fake obligation |
|---|---|
| Hold TTL | Expires in real time against the injected clock |
| Availability races | A scenario can sell out a bag between load and reserve |
| Payment | Configurable delay, plus `pendingVerification` → `captured` / `failed` / `uncertain` |
| **Money** | Only the fake computes breakdowns. It **rejects** any client-supplied total — an R1 violation must fail loudly in development. |
| Cancellation eligibility | Computed by the fake from `policyValues`, never by the client |
| Coverage | Can return each of A10's three states |
| Errors | Every §7.1.5 code is inducible |
| Offline | Simulable, including the A1 offline-token path and the A3 unresolved-payment resume |

### Scenario switching

A dev-only scenario selector (not present in release builds) forces any of the above. This is what makes
§C8 gate 1 — *"all C1 states reachable in the mock layer"* — achievable rather than aspirational, and it
doubles as the fixture set for widget tests.

### Determinism

A `Clock` abstraction is injected everywhere time is read. Pickup windows, countdowns, hold expiry, and
token validity are all testable without waiting, and golden tests are stable.

---

## 7.11 Contract requirement traceability

| Amendment | Contract mechanism |
|---|---|
| A1 | Three-layer `pickup-token`; `offlineToken` fetched at confirmation |
| A2 | Hold frozen by `POST /orders` |
| A3 | `GET /orders/unresolved` |
| A6 | Server obligation, §7.8 |
| A7 | `acceptedEnvelopes` as a set |
| A8 | `scarcity` enum in lists; exact count only on `/bags/{id}` |
| A9 | `remainingAllowanceForCustomer`; `purchase_cap_exceeded` |
| A10 | `GET /coverage` |
| A11 | `POST /checkout/quote` |
| A12 | Client-side timeout; no contract surface |
| A13 | `chargeState` |
| A14 | Client-side cadence; `no-store` on order status |
| A15 | `cancellation-eligibility` |
| A16 | `food_safety` issue class |
| A17 | Single `PUT /saved/{id}` with `watching` |
| A18 | Public `/legal`, `/help`, `/config` |
| A19 | `policyValues` |
| A20 | `deletion-eligibility`, soft delete, `reactivateBefore` |
| A21, A22 | Presentation-only; no contract surface |
| A23 | `POST /auth/device`; merge on verify |
| A24 | Rotating single-use refresh with family revocation |

---

## Open

- **A15 value unsigned** — `cancellationCutoffMinutesBeforeWindow: 60` is proposed, not approved. It is
  now a config value, so changing it is a one-line change rather than a rework.
- **Pickup-confirmation counterparty** (Phase 1 open item) — the contract supports both merchant-side QR
  scan and manual fallback-code entry. Neither is exercised by a V1 client; both are specified so the
  merchant surface has a target.
- **GST §9(5) characterisation** — unresolved, and harmless: `PriceBreakdown` carries server-supplied tax
  line labels, so any outcome is a server change.
