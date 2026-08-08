# Phase 3 — User Journeys

Status: for approval · Depends on: [Phase 1](01-business-understanding.md), [Phase 2](02-information-architecture.md) · Consumers: Phases 4–9

Six journeys, built directly on the Phase 2 §2.2 state machines so journeys and domain stay in
lockstep. Each records entry points, decision branches, failure modes, exit states, and the
**emotional low points** that Phases 5 and 6 must design against.

> §3.7 lists six findings that **amend Phase 2**. They are the reason this phase exists before any
> screen is designed.

---

## 3.0 Two structural decisions that shape every journey

### D1 — Deferred authentication

**Anonymous discovery is allowed. Auth is gated at add-to-cart, not at app open.**

Requiring an OTP before showing any value is the single largest first-run drop-off in Indian
consumer apps, and it is a particularly bad trade here: a first-time user has no reason to believe
"discounted surplus food" is real until they see a ₹120 bag worth ₹350 from a bakery they recognise
two streets away. That proof has to come before the ask.

Consequences we accept:
- Dietary preference and search location must persist **locally** for anonymous users, then migrate
  to the account on signup. No silent loss of the user's stated constraints.
- The auth wall lands mid-intent, which is a genuine interruption. It must return the user to
  *exactly* the bag they wanted (§3.1 step 8) — and must re-validate availability on return, because
  bags sell out during OTP.

### D2 — Permission requests are placed at the moment of demonstrated need

| Permission | Asked | Why there |
|---|---|---|
| Location | After onboarding, before first Discover | Unavoidable — there is no product without a radius. Preceded by a custom primer screen explaining the value; the OS dialog is never the first thing the user sees. |
| Notifications | **After the first successful reservation** | Maximum consent likelihood: the user now has money at stake and a real need for a pickup reminder. Asking at onboarding trades a permanent denial for nothing. Android 13+ requires a runtime `POST_NOTIFICATIONS` grant, so a denial here is expensive and hard to recover. |
| Camera | Never in V1 | The customer *presents* a QR; they do not scan one. Noted so nobody adds it reflexively. |

---

## 3.1 Journey 1 — First run → first reservation

The highest-drop-off path in the product.

**Entry:** app icon, first launch. **Precondition:** no session, no cached location.

| # | Step | Branches and failure modes |
|---|---|---|
| 1 | **Splash** — check session, fetch remote config, force-update gate, **unresolved-payment recovery check** (§3.6 step 5) | Force-update required → blocking screen with store link · Config fetch fails → proceed on bundled fallback taxonomy, never block |
| 2 | **Onboarding carousel** (3 screens) | Skippable. Copy must fight the leftovers stigma from screen one: *made today · up to 70% less · collect near you.* Not "rescue waste" — that frames the user as a bin. |
| 3 | **Location primer** (our screen, not the OS dialog) | Explains the value, then triggers the OS request |
| 4 | **OS location request** | **Granted precise** → proceed · **Granted approximate** (Android 12+, ~1–3 km) → *acceptable*, proceed; a 5 km discovery radius tolerates coarse location, so we must not hard-require precise · **Denied** → manual location entry (locality search or map pin) · **Denied permanently** → same manual path plus a settings deep link. **Never a dead end.** |
| 5 | **Dietary preference** — 4 large options + "show me everything" | Skippable, defaults to show-all. Framed as *"So we only show food you can eat."* Persisted locally (D1). |
| 6 | **Discover** | **Supply exists** → feed · **No supply in radius** → §3.1a |
| 7 | **Bag detail** | Bag sold out while browsing → sold-out state with alternatives at the same merchant |
| 8 | **Reserve → auth wall** — phone → OTP → return | OTP not received → resend cooldown, then voice-OTP and WhatsApp fallback · Wrong OTP → attempt limiting with a clear remaining-attempts count · **Bag sold out during OTP** → *"This one just went."* + 3 alternatives + one-tap watch. This race is common, not theoretical. |
| 9 | **Profile setup** (name only) | Minimal. Everything else is deferred to Account. |
| 10 | **Cart** — server hold created, countdown banner starts | Hold expires while the user hesitates → clear expiry state, one-tap re-reserve with revalidation |
| 11 | **Checkout** — UPI pre-selected, server `PriceBreakdown` rendered | See §3.6 for every payment branch |
| 12 | **Reservation confirmed** | |
| 13 | **Notification primer** — *"We'll remind you when it's time to collect"* → OS request | Denied → in-app Orders badge and a persistent pickup reminder card carry the load; the user must still be able to complete a pickup with notifications off |

**Exit states:** `confirmed` order (success) · abandoned at auth wall · abandoned at payment ·
zero-supply notify-me registration.

**Emotional low points:** the OTP wait (SMS latency is outside our control — the screen must feel
alive, with an honest countdown and early fallback offers) · the auth wall interrupting real intent ·
a bag vanishing mid-flow · the payment app-switch.

### 3.1a The zero-supply branch

An empty map is an uninstall, so this is a designed destination rather than an empty list.

Contents: honest statement — *"We're not live in Indiranagar yet"* · **notify-me-here** (the primary
CTA, and our only lever for measuring latent demand by locality) · nearest live area with distance
and a one-tap switch · expected-availability education (*"most bags appear between 7 and 10 pm"*) so
a user who arrived at 11 am understands the product rather than concluding it is broken.

What it must never be: a spinner, a generic "no results", or a filter-reset suggestion when the
cause is no supply at all. Those three read as a broken app.

---

## 3.2 Journey 2 — Returning user → reserve

The habitual evening loop. **Entered from a push notification, not the app icon** — supply is
discovered late and arrives in bursts, so the notification *is* the entry point.

**Target: three taps, under 30 seconds, from notification to confirmed.**

**Entry:** `newBagsNearby` (~7:30 pm) or `watchedMerchantListed`.

| # | Step | Branches and failure modes |
|---|---|---|
| 1 | Push tapped → cold or warm start → deep link resolves | Access token expired → **silent refresh, invisible to the user** · Refresh token invalid → session-expired re-auth **preserving the destination**, then continue to the bag |
| 2 | Bag detail (deep-linked) | **Bag already sold out** — highly likely under burst supply. See below. |
| 3 | Reserve → hold | |
| 4 | Checkout with remembered UPI app | |
| 5 | Confirmed | |

**The sold-out-from-notification problem.** Arriving from a notification at a bag that is gone
reads as bait-and-switch, and it is the fastest way to train users to ignore our push. Two
mitigations, one per layer:

- *Product:* the sold-out screen must be an opportunity, not an error — *"Gone in 4 minutes"* (which
  also teaches urgency), alternatives at the same merchant and nearby, and one-tap watch on that
  merchant.
- *Contract (Phase 7):* notification fan-out must be quantity-aware. Notifying 500 users about 3
  bags manufactures 497 bad experiences. The app cannot fix this alone; it is recorded as a backend
  requirement.

**Exit states:** `confirmed` · sold-out with watch registered · sold-out with churn risk.

---

## 3.3 Journey 3 — Pickup and collection

**Entry:** `pickupWindowOpening` push (T−30 min), or the Orders tab.

The Pickup screen is the highest-stakes surface in the product — the user is standing in a shop with
staff waiting.

**Pickup screen contents:** window countdown · merchant name and storefront photo · landmark line
and floor/shop number · **Directions** CTA · QR · fallback code · pickup instructions · *"bring your
own bag"* (sustainability, and practical in India where carry bags are chargeable).

| # | Step | Branches and failure modes |
|---|---|---|
| 1 | Pickup screen opened | Order was cancelled by the merchant while this screen is open → **must interrupt in-app immediately**, not merely arrive as a push. This is precisely what the §2.5 30-second foreground poll exists for. |
| 2 | Travel — hand off to the native maps app | Return to app must land back on the Pickup screen, not the Discover tab |
| 3 | Arrival → present QR. **Screen brightness auto-maximised.** | Dim screens under shop lighting are a real scan-failure cause; this is a one-line fix for a recurring support ticket |
| 4 | Merchant scans → `collected` | |
| 5 | Success → review prompt (`rateYourPickup`, T+1 h) | |

**Branches at the counter:**

| Situation | Path |
|---|---|
| Scanner works | → `collected` |
| Merchant cannot scan (no device, poor network, unfamiliar staff) | Merchant enters the **fallback code** in their portal → `collected` |
| Merchant has no working device at all | → **Report an issue** → support-mediated resolution. **The customer may not self-mark an order collected.** This is a deliberate limitation: self-confirmation would break merchant settlement integrity and create an obvious fraud vector. Recorded openly rather than papered over. |
| Merchant says no bag is ready | → Report an issue → immediate full-refund path (§3.4 machinery) |
| Customer arrives after the window closed | Order is already `expiredUncollected` → §3.5 |

**Emotional low points:** standing at the counter while staff are confused about what the app is —
the fallback code and clear pickup instructions exist for this exact minute · a QR that will not
scan · being told there is no bag after travelling for it.

---

## 3.4 Journey 4 — Merchant cancels → refund

The trust-defining journey. We either keep this customer or lose them permanently.

**Entry:** `merchantCancelled` push (**Max** priority), or in-app interrupt if the Pickup screen is open.

| # | Step | Notes |
|---|---|---|
| 1 | Interrupt / push → Order detail | If the user is en route or at the shop, a push alone is insufficient — the open Pickup screen must update in place |
| 2 | Unambiguous statement | *Not your fault · full refund, already started · no action needed from you.* No policy language, no blame-shifting to the merchant |
| 3 | **Refund timeline** — initiated → processing → credited, with `expectedByAt` | Indian refunds to UPI and cards realistically take 3–7 working days. **Stated upfront, honestly.** A user who discovers the delay themselves assumes theft; a user told in advance waits. |
| 4 | Immediate remedy | Alternatives available nearby right now. Goodwill credit deferred to V1.1 |
| 5 | `refundFailed` | **Proactive support escalation — we contact the user, not the reverse.** A failed refund that waits for a complaint is a lost customer and a public review |

**Exit states:** `cancelledByMerchant` + `refunded` (recovered) · + `refundFailed` (escalated) ·
churn.

**Emotional low point:** receiving this while already standing outside the shop. Design implication
is concrete: real-time invalidation on the Pickup screen, and the cancellation copy must lead with
the refund, not with the cancellation.

---

## 3.5 Journey 5 — Customer no-show → `expiredUncollected`

The journey with no good outcome, which is exactly why it needs designing.

| # | Step | Notes |
|---|---|---|
| 1 | `pickupClosingSoon` at T−45 min (**Max** priority) | The last chance. Must be impossible to miss — and it must still work for users who denied notifications, via an in-app pickup reminder card and an Orders badge |
| 2 | Window closes → `expiredUncollected` | |
| 3 | Post-hoc screen | What happened · why no refund applies · what to do differently |
| 4 | One-time goodwill on first offence | |

**The honest hard part:** the user paid and received nothing. **Policy: no refund on customer
no-show** — the merchant held the bag out of sale and has almost certainly discarded it, so
refunding would push our failure onto the merchant and destroy the supply side. The policy is
correct, and the user will still feel wronged.

Three design obligations follow, all of them non-negotiable:
1. The no-refund term is **visible at checkout**, in plain language, not buried in Terms.
2. The T−45 min notification is treated as a **transactional** alert — it cannot be muted by
   turning off marketing pushes (§2.6 constraint 4 exists for this).
3. The post-expiry screen is **non-accusatory**. The user already knows they made a mistake; telling
   them so converts a lapsed order into a lost customer.

**Repeat no-shows:** tracked in V1, not punished. Merchant-protection measures need data before
policy.

---

## 3.6 Journey 6 — UPI payment ambiguity → verification

The most technically subtle journey, and the single most likely place for a user to believe they
have been charged twice.

| # | Step | Branches |
|---|---|---|
| 1 | Checkout → UPI → intent deep link → **app-switch** to GPay / PhonePe / Paytm | No UPI app installed → fall back to collect-request or card |
| 2 | User pays, abandons, or times out. Return to our app with an **indeterminate** result | |
| 3 | Client enters `pendingVerification` and polls the server verification endpoint with backoff | |
| 4 | **The most important copy in the app:** *"Confirming your payment — please don't pay again. We're checking with your bank."* | Not a bare spinner. Double payment is the number one user fear and the number one support cost on Indian UPI flows; the instruction not to retry must be explicit |
| 5 | Outcomes | `captured` → Confirmed · `failed` → retry with the hold preserved if TTL remains, revalidated per R2 · **Still pending after ~30 s** → *"Taking longer than usual. We'll notify you within X minutes. Your money is safe."* → the user may leave the screen; resolution arrives by push |
| 6 | **Cold-start recovery** | The user killed the app mid-app-switch. On next launch, Splash **must** check for an unresolved payment and resume verification. Without this branch: money debited, no order, no trace. See amendment A3. |
| 7 | **Hold-expiry collision** | Payment captured, but the hold expired during verification and the bag went to someone else. → automatic full refund, apology, alternatives. Prevented at the contract level by amendment A2. |

**Exit states:** `confirmed` · `paymentFailed` (retryable) · captured-then-refunded (collision) ·
abandoned.

**Emotional low point:** the few seconds after returning from the UPI app, not knowing whether ₹120
left the account and whether the bag is theirs. Every design choice on this screen serves that
moment.

---

## 3.7 Findings that amend Phase 2

Six issues these journeys surfaced. **These require approval, as they change Phase 2.**

| # | Amendment | Origin | Why it matters |
|---|---|---|---|
| **A1** | **`PickupToken` needs a window-duration offline-valid token in addition to the rotating payload.** | §3.3 | Phase 2 §2.1 specified a QR rotating every ~60 s, which silently assumes connectivity *inside the shop* — often the worst-connected place in the journey, and frequently a basement or back-of-shop counter. Pickup must work fully offline. Revised design: a signed token valid for the whole pickup window, cached on the device at order confirmation, **plus** the rotating payload when online, **plus** the static fallback code. Three layers because this is the one step that absolutely cannot fail. |
| **A2** | **A cart hold must not expire while its payment is `pending` or `pendingVerification`.** | §3.6 step 7 | Otherwise a user can be debited for a bag that was concurrently sold to someone else. Becomes an explicit Phase 7 contract requirement. |
| **A3** | **Splash requires an unresolved-payment recovery branch.** | §3.6 step 6 | Without it, killing the app mid-UPI-app-switch produces a debit with no order. Adds a state to the Splash screen definition in Phase 5. |
| **A4** | **Auth is deferred to add-to-cart; discovery is anonymous.** | D1 | Phase 2's surface map implied auth-then-browse. Requires anonymous local persistence of dietary preference and search location, with migration to the account at signup. Affects the Phase 4 route guard design. |
| **A5** | **Notification permission is requested after the first reservation, not during onboarding.** | D2 | Moves a destination from area A to the end of the Reserve & Pay flow. |
| **A6** | **Notification fan-out must be quantity-aware** (backend requirement, recorded not solved). | §3.2 | Notifying 500 users about 3 bags manufactures 497 bad experiences and trains users to ignore push. The app handles the race gracefully; only the backend can prevent it. |

---

## 3.8 Cross-journey design themes for Phases 5–6

1. **Time is always visible.** Every screen touching an order shows window state or countdown. The product's core mechanic is a clock.
2. **Never dead-end on a permission denial.** Location denied, notifications denied — both have complete alternative paths. A denied permission degrades the experience; it must never end it.
3. **Money states are explained, never spun.** Pending, failed, refunding, and refunded each get plain-language copy with an honest timeframe.
4. **Sold-out is a first-class state, not an error.** It is a *frequent* outcome of a burst-supply marketplace and must feel like discovery, not failure.
5. **Blame is never assigned to the user.** Including in §3.5, where it would technically be accurate.
6. **Every async surface has a skeleton, and every empty surface has a reason and a next action.**
