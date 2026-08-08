# Phase 5d — Screen Definitions: Orders & Pickup

Status: for approval · Conventions: [05-index](05-screen-definitions-index.md) · Routes: [Phase 4 §4.2](04-navigation-flow.md) · Journeys: [Phase 3 §3.3–3.5](03-user-journeys.md)

**Surface reconciliation.** Phase 2 §2.4 listed 7 destinations. They resolve to **5 screens plus 1
dialog**:

- *Active orders* and *Order history* are **segments of one route** (`/orders`). They share the card
  component, the refresh machinery, and the status vocabulary; splitting them into two routes would
  duplicate all of it for no user benefit.
- *Cancel order* is a **dialog**, not a route, per §4.6.

> Amendments: **A14** (§5d.3) · **A15** (§5d.5) · **A16** (§5d.6).

---

## 5d.1 Orders — `/orders`

**Purpose.** Give the user certainty about what they have committed to, and when.

**User goals.** Primary: *"What do I need to collect, and when?"* Secondary: find a past receipt.

**Components.**

| Region | Contents |
|---|---|
| Segmented control | **Active** · **Past** |
| **Hero card** | The next imminent pickup, promoted out of the list |
| List | Order cards — order code · merchant · bag title · pickup window with live state · status chip · thumbnail |
| Past | Grouped by month, with terminal status |

**The next pickup is a hero card, not a list row.** The common case is exactly one active order, and a
user in that case should not have to parse a list to find the one thing they need. The hero carries the
countdown, **Directions**, and **Show pickup code** as its primary action — the three things a user
opens this tab to get.

**Orders tab badge.** Counts orders whose window is open or opening within the hour. This is the
in-app substitute that carries the load when notification permission was denied (§5c.9), so it is
load-bearing rather than decorative.

**States.** `loading` (skeleton) · `loaded` · `refreshing` (on foreground) · `emptyActive` ·
`emptyPast` · `emptyBoth` · `stale` · `offline` · `error`.

**Empty states.**

| Case | Treatment |
|---|---|
| No active orders | *"Nothing to collect right now"* + Discover CTA. Framed as a neutral fact — this is the steady state for most users most of the time and must not read as an error. |
| No past orders | *"Bags you've collected will appear here"* |
| Both empty (new user) | One combined state pointing at Discover |

**Error states.** Fetch fails with cache present → cached content + stale banner (order history is
persistently cached, §2.5). No cache → error with retry.

**Validation.** None.

**Accessibility.** Each card is one merged node: *"Order SV-7K2M. Bakery Surprise Bag from Sweet Crumb.
Collect today, 8 to 10 pm. Opens in 45 minutes."* Status chips carry icon **and** text. Countdowns are
polite live regions at thresholds only. The segmented control uses tab semantics with selected state.
The hero's primary action is labelled with its effect: *"Show pickup code for order SV-7K2M."*

---

## 5d.2 Order detail — `/orders/:orderId`

**Purpose.** The receipt, and the single source of truth for one order.

**User goals.** Verify what was bought and paid; find pickup information; get help.

**Components.**

| Region | Contents |
|---|---|
| Status banner | State-specific, prominent — the answer to why the screen was opened |
| Identity | Order code |
| **Bag snapshot** | Title · dietary envelope · quantity — from the immutable snapshot (§2.1) |
| **Merchant snapshot** | Name · address · landmark · phone — snapshot, so a renamed or delisted merchant still renders as purchased |
| Time | Pickup window |
| **Price breakdown** | Itemised snapshot · all-inclusive total |
| Payment | Method + masked identifier |
| **Legal block** | Merchant legal name · FSSAI licence · grievance officer — Consumer Protection (E-commerce) Rules 2020 |
| Share | **Share receipt** (formatted text, V1) |
| Actions | Status-dependent, below |

**Share receipt** ships as formatted text in V1 rather than a PDF. Users need it for expense claims and
household accounting; a PDF pipeline is disproportionate for the value, and text is more useful in a
WhatsApp-mediated culture. Recorded as a deliberate V1 limitation, not an oversight.

**Status-dependent actions.**

| Status | Actions |
|---|---|
| `pendingPayment` / `paymentFailed` | Complete payment · Retry |
| `confirmed` / `readyForPickup` | **Show pickup code** (primary) · Directions · Cancel · Report an issue |
| `collected` | Rate & review · Report an issue · **Watch this merchant** |
| `cancelledByMerchant` / `cancelledByCustomer` | View refund |
| `expiredUncollected` | §3.5 content below · Report an issue |

*Watch this merchant* replaces a reorder action. Reordering is meaningless here — the bag was an
ephemeral daily instance (§2.7.2) and does not exist tomorrow.

### The `expiredUncollected` state (§3.5)

The one state with no good outcome, and therefore the one needing the most careful copy. Requirements:

- **Non-accusatory.** The user already knows they missed it. Telling them so converts a lapsed order
  into a lost customer.
- States plainly **why no refund applies** — the merchant held the bag out of sale and could not sell
  it — without positioning the merchant as the villain.
- Offers **one-time goodwill on a first occurrence.**
- Offers **Report an issue** for the user who believes they *did* attend (§3.3 covers the merchant-side
  failures that produce this).

**States.** `loading` · `loaded` (one variant per status) · `notFound` · `stale` · `offline` · `error`.

**Error states.** `notFound` — order deleted, or belonging to another account — resolves to a scoped
not-found within the tab (§4.8). A week-old notification tapped by a since-logged-out-and-back-in user
is an ordinary event.

**Validation.** None.

**Accessibility.** The status banner is announced **assertively on entry** — it is the answer the user
came for. The price breakdown is a semantic label–value list. FSSAI licence and reference numbers are
announced character by character. Masked payment identifiers read correctly: *"UPI ID ending four two
one zero."*

---

## 5d.3 Pickup — `/orders/:orderId/pickup`

**Purpose.** Get the user to the right counter and let them prove the reservation — **with or without a
network connection** (A1).

**User goals.** Find the shop. Show proof. Not look foolish in front of staff.

**Components**, ordered by when they are needed:

| Priority | Element |
|---|---|
| 1 | **Window state / countdown** — *"Opens in 45 min"* · *"Collect now — closes in 1h 12m"* · *"Closing soon — 22 min"* |
| 2 | **QR code**, large and high-contrast |
| 3 | **Fallback code**, large and monospace — **always visible** |
| 4 | Merchant name · storefront photo |
| 5 | **Landmark · floor / shop number** — the find-the-shop block |
| 6 | **Directions** |
| 7 | Pickup instructions · order code · bag title · quantity · *bring your own bag* |
| — | Offline indicator when serving the cached token · Report an issue · Cancel (within policy) |

**The fallback code is never hidden behind a "can't scan?" link.** Hiding it means the user hunts
through the UI while staff wait — precisely the §3.3 emotional low point. It is presented as a peer of
the QR, not a remedy for its failure.

**Screen brightness is maximised on entry and restored on exit** (§3.3), **with a manual toggle.** A
forced brightness change is an accessibility problem for photosensitive users, so the user retains
control rather than having it imposed.

### A1's three token layers

| Layer | Source | When rendered |
|---|---|---|
| 1 | Rotating `qrPayload`, refreshed ~60 s | Online |
| 2 | **Window-duration signed token**, cached at order confirmation | Offline, or when rotation fails |
| 3 | Static `fallbackCode` | Always |

**States.** `windowUpcoming` · `windowOpen` · `closingSoon` (< 30 min) · `windowClosed` ·
`tokenRotating` · `tokenOffline` · `collected` · `merchantCancelled` · `notFound` · `error`.

**The QR is shown even before the window opens**, with *"Opens at 8 pm"* stated prominently. Merchants
do mark bags ready early (`readyForPickup` is a real status), and hiding the code creates exactly the
counter confusion this screen exists to prevent.

**`collected` must update in place**, while the user is standing at the counter watching the screen.
See A14.

**`merchantCancelled` must interrupt in place** (§3.4) — a push alone is insufficient for a user who is
already at the shop.

**Error states.**

| Failure | Handling |
|---|---|
| Token rotation fails while online | **Silently fall back to layer 2** + offline indicator. Never show an error when a valid cached token exists. |
| Order older than its window | Route to the `windowClosed` treatment, then §3.5 |
| `notFound` | Scoped not-found (§4.8) |

**Validation.** None.

**Accessibility.**

- **A QR code is inaccessible by nature, so the fallback code must be independently sufficient** —
  announced character by character, copyable, and presented as an equal. A blind user's viable paths
  are reading the code aloud or handing over the phone; both must work without sighted assistance.
- **The QR has a minimum size floor.** At `textScaleFactor` 2.0 the page **scrolls** rather than
  shrinking the QR. An unscannable QR is a total failure of the screen, so text scaling must never
  compete with it for space.
- Countdown: polite, thresholds only. `collected` and `merchantCancelled`: **assertive**.
- Directions CTA names its destination.

### Amendment A14 — pickup polling cadence

**Finding.** §2.5 specified a 30-second poll while the Pickup screen is foregrounded. At the counter
that means the user can stare at an unchanged screen for up to half a minute *after* the merchant has
scanned, while staff wait and both parties wonder whether it worked. That half-minute is the worst
thirty seconds in the product.

**Change.**

| Condition | Cadence |
|---|---|
| Foregrounded **and** window open | **5 s** |
| Foregrounded, window not yet open | 30 s |
| Backgrounded | None — push only |

Push remains the primary invalidation signal; polling is the fallback for the exact moment when the
user cannot tolerate latency. The cost is a handful of extra requests confined to an open pickup
window.

---

## 5d.4 Refund status — `/orders/:orderId/refund`

**Purpose.** Make money-in-transit visible and believable (§3.4).

**User goals.** Know how much, to where, and by when.

**Components.** Amount, prominent · **three-step timeline** — *Refund started → Sent to your bank →
Credited* — each with a timestamp or expected date · **`expectedByAt` stated honestly** (*"Usually by
2 Aug — 3 to 7 working days"*) · destination (*"to your UPI ID ending 4210"*) · reason · **bank
reference number** · Help.

**Never the word "processing" without a date.** An open-ended "processing" is what converts a waiting
customer into someone who believes they have been robbed. Phase 1 §3.4 committed to stating the 3–7
working day reality upfront; this screen is where that promise is kept.

**States.** `loading` · `initiated` · `processing` · `credited` · `failed` · `notFound` · `error`.

**Error states.** `failed` → **proactive framing** (§3.4): *"We couldn't complete this refund. Our team
is on it and will contact you by 29 July."* Plus a support CTA. The user is never left to chase their
own money.

**Validation.** None.

**Accessibility.** The timeline is an ordered list with each step's state announced — *"Step 2 of 3,
sent to your bank, completed 26 July."* Amount announced with currency. Reference number announced
character by character; it exists to be quoted to a bank.

---

## 5d.5 Cancel order — dialog, no route (§4.6)

**Purpose.** Allow cancellation within policy, with the money consequence stated *before* the user
commits.

**Components.** Title · **refund consequence, stated explicitly** · cutoff explanation · optional
reason picker · **Confirm** / **Keep reservation**.

**States.** `idle` · `submitting` · `success` · `error` · `notAllowed` (past cutoff).

**Error states.** Cancellation fails → retry, order unchanged. A failed cancellation must never leave
ambiguity about whether it took effect.

**Validation.** The cutoff and the refund outcome are **server-determined**. The client renders the
server's answer and never computes eligibility locally — the same principle as R1, extended from money
to policy outcomes.

**Accessibility.** Dialog traps focus and restores it on dismiss. **The consequence sentence is
announced first, before the buttons.** The confirming button states the money outcome — *"Cancel
reservation and get ₹132 back"* or *"Cancel reservation — no refund"* — never a bare *"Confirm"* on a
destructive financial action.

### Amendment A15 — cancellation policy

**A commercial decision that needs your sign-off**, since it sets a customer-facing term.

**Proposed:** **free cancellation until 1 hour before the pickup window opens; no refund after that.**

Reasoning: once inside that hour the merchant has set the bag aside and stopped offering it, so a late
cancellation transfers our flexibility onto their loss — and the supply side is the scarce side of this
marketplace (Phase 1 §1). One hour is enough for a genuine change of plan while keeping the merchant's
exposure bounded.

**Requirements this creates:**
- Stated at checkout adjacent to the pay CTA (§5c.2), alongside the no-show term.
- Stated in this dialog with the live outcome for *this* order.
- Phase 7 must return both the cutoff timestamp and the resulting refund outcome; the client never
  derives them.

---

## 5d.6 Report an issue — `/orders/:orderId/issue`

**Purpose.** Self-serve resolution of the top support drivers (Phase 1 risk 3; §3.3 counter branches).

**User goals.** Get the problem fixed without phoning anyone.

**Components.** Issue-type picker **scoped to the order's status** · description · photo attachment
(≤ 3) · **stated SLA** · Submit.

**Scoping the picker to status** matters: a `collected` order cannot have "no bag was ready", and
offering it invites mis-filed reports that then need human triage — the cost we are trying to avoid.

| Order status | Issue types |
|---|---|
| `confirmed` / `readyForPickup` | Merchant closed · No bag ready · Wrong location · Can't make it |
| `collected` | Bag differed from description · Quality problem · Quantity wrong · **Food safety concern** |
| `expiredUncollected` | I was there but couldn't collect · Merchant refused to hand over |

**States.** `idle` · `typeSelected` · `uploading` · `submitting` · `submitted` · `error`.

**Error states.** Photo upload fails → **submit the report without photos** and offer upload retry
afterwards. Losing a report because an image failed is an unforced error.

**Validation.** Type required · description minimum 10 characters for free-text types · photos ≤ 5 MB
each, JPEG/PNG/WebP, maximum 3 · **EXIF location stripped before upload** — a photo of food taken at
home embeds the user's home coordinates, and we have no reason to receive them.

**Accessibility.** Issue types are radio semantics. Photo thumbnails are labelled with individual
remove actions. The character counter is a polite live region. Submission outcome is announced
assertively. The SLA is stated in text, not implied.

### Amendment A16 — food safety reports are escalated, not queued

**Finding.** Treating *"the food made me ill"* as one option in a support dropdown makes an existential
risk (Phase 1 risk 6) wait its turn behind quantity complaints.

**Change.** A distinct path:

1. **Immediate consumption advisory** on selection — *"If you have not eaten this, please don't."*
   Shown before the form, because the next few minutes matter more than our ticket.
2. **Immediate acknowledgement** with a reference number rather than a generic thank-you.
3. **Separate, faster SLA**, stated explicitly.
4. Routed as a distinct issue class in the Phase 7 contract, so it can be alerted on rather than
   polled by a support queue.
5. Merchant-side implications (pausing listings pending review) are out of V1 scope but recorded as a
   downstream requirement.

---

## Handed to Phase 6

New design-system requirements: **hero pickup card** · **order status chip** (one per `OrderStatus`,
icon + text) · **QR display block** with minimum-size floor and brightness control · **monospace code
display** (character-readable) · **three-step timeline** component with per-step state · **status
banner** (one treatment per order status) · **legal disclosure block** (shared with §5b.8) ·
**destructive dialog** with outcome-bearing button labels · **photo attachment row** with per-item
remove · **advisory block** (A16, distinct from error and info treatments).
