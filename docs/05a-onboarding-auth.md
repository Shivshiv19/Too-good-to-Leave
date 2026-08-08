# Phase 5a — Screen Definitions: Onboarding & Auth

Status: for approval · Conventions: [05-index](05-screen-definitions-index.md) · Routes: [Phase 4 §4.2](04-navigation-flow.md)

11 screens: 8 in the onboarding/auth path, 3 blocking states owned by Splash.

> §5a.12 raises **amendment A7**, which changes the `Customer.dietaryPreference` model from Phase 2.

---

## 5a.1 Splash — `/splash`

**Purpose.** Resolve every fact the §4.3 guard chain needs synchronously, and gate clients we have
declared unsafe. Not a decorative delay — it is the only place asynchronous bootstrap can happen.

**User goals.** None. The user's goal is that this screen not exist. Success is measured in
milliseconds, not comprehension.

**Components.** Wordmark, centred · deferred progress indicator (§C2) · timeout affordance.

**Work performed.** Read tokens from secure storage · fetch remote config (force-update, maintenance,
taxonomy ETag) · read cached location · **check for an unresolved payment (A3)** · resolve
`SessionState` flags.

**States.**

| State | Treatment |
|---|---|
| `bootstrapping` (0–400 ms) | Wordmark only. No indicator — see the 400 ms rule. |
| `bootstrappingSlow` (> 400 ms) | Wordmark + indeterminate indicator |
| `timeout` (> 8 s) | *"Taking longer than usual"* + **Retry**, plus **Continue** if a cached session exists |
| `outcome` | Hands off to the guard chain — normal · force-update · maintenance · payment-resume |

**Empty states.** None.

**Error states.**

| Failure | Handling |
|---|---|
| Remote config unreachable | **Proceed** on bundled fallback taxonomy. Config is never a launch blocker. |
| Secure storage read fails | Treat as signed out, clear tokens, continue. **Must not crash.** This is a real occurrence, not a hypothetical: Android Keystore entries are invalidated by biometric enrolment changes, and iOS Keychain items can be unrestorable after a device restore or migration. A crash loop on launch after the user changed their fingerprint is unrecoverable without a reinstall. |
| Offline **and** an unresolved payment exists | Cannot verify offline. **Do not block launch.** Proceed; verification resumes on the first connectivity event, and the order appears in Orders as `confirming` so the money is visibly accounted for. |
| Offline, no session | Proceed to onboarding — it is entirely local |

**Validation.** None.

**Accessibility.** Wordmark labelled with the app name; `SemanticsService.announce('Loading')` once
on entry to `bootstrappingSlow`, not repeatedly. Reduced motion: no wordmark animation. Focus must
not be trapped — a screen reader user must reach the timeout retry.

**Performance.** Contributes to the < 2 s cold-start budget (Phase 1 §3.6). Only two network calls
sit on the critical path, both with non-blocking fallbacks.

---

## 5a.2 Onboarding carousel — `/onboarding`

**Purpose.** Establish that the offer is real, and defuse the leftovers stigma (Phase 1 §3.2), before
any permission or account is requested.

**User goals.** Understand what this is in under 15 seconds; decide whether to continue.

**Components.** `PageView` of 3 · illustration · headline · one line of body · page indicator ·
persistent **Skip** · **Next** / **Get started**.

**Content.** Each screen answers one objection:

| # | Answers | Direction |
|---|---|---|
| 1 | *"Is this old food?"* | Made today, unsold at closing time |
| 2 | *"Is the discount real?"* | Concrete: a ₹350 bag for ₹120 |
| 3 | *"What do I actually do?"* | Collect nearby, inside a time window |

Copy must not frame the user as a waste-disposal service. "Rescue food from the bin" positions the
customer as the bin. The value proposition is *good food, much cheaper* — sustainability is the
reason to feel good afterwards, not the reason to buy.

**States.** `page1` · `page2` · `page3` · `skipped`. Fully local; no async states.

**Empty / error states.** None — no network dependency by design. A first launch on a dead network
must still reach location setup.

**Validation.** None.

**Accessibility.** Page indicator announces *"Page 2 of 3"*. **Swipe must have a button equivalent** —
`Next` is always present, since swipe-only navigation excludes users with motor impairments.
Illustrations are decorative → `ExcludeSemantics`. Focus order: headline → body → Next → Skip.
Reduced motion: cross-fade instead of slide.

**Note.** Re-reachable later as *"How it works"* under Help (§05f), so the only explanation of the
product is not one-time-only.

---

## 5a.3 Location primer — `/location-primer`

**Purpose.** Earn the location grant by explaining the value first. **The OS dialog is never the
user's first encounter with the request** (D2).

**User goals.** Understand why location is needed; retain a way forward if unwilling to grant it.

**Components.** Map-motif illustration · headline *"Find food near you"* · two value lines · primary
**Allow location** · secondary **Enter location manually**.

**States.** `initial` · `requesting` (OS dialog visible) · `grantedPrecise` · `grantedApproximate` ·
`denied` · `deniedPermanently`.

**Branch handling.**

| Outcome | Action |
|---|---|
| Precise | → Discover |
| **Approximate** (Android 12+, ~1–3 km) | → Discover. **Accepted, not re-prompted.** A 5 km discovery radius tolerates coarse location; nagging for precise buys nothing and costs goodwill. Precise is re-requested only at the Pickup screen, where walking-distance accuracy genuinely matters. |
| Denied | → `/location-setup` |
| Denied permanently | → `/location-setup` + a settings deep link, offered as information rather than pressure |

**Empty states.** None.

**Error states.** OS dialog fails to present (rare, occurs on some OEM builds) → fall through to
manual entry after a 3 s timeout rather than leaving a dead button.

**Validation.** None.

**Accessibility.** **The manual option must carry genuine visual weight — not a greyed-out
afterthought.** For a user who will never grant location, it is the only path, and de-emphasising it
to inflate grant rates is a dark pattern. Both CTAs ≥ 48 dp. The `requesting` state announces that a
system dialog has opened, since screen-reader focus moves out of the app.

---

## 5a.4 Location setup — `/location-setup`

**Purpose.** Establish a discovery anchor by *any* means. **Must be fully functional with location
permission permanently denied** (§4.9 requirement 2).

**User goals.** Set where to look for food, quickly and correctly.

**Components.** Search field with locality/pincode autocomplete · **Use current location** (only when
permitted) · map with centre pin · resolved-address card · **Confirm** · saved locations list (only
when authenticated).

**States.** `idle` · `searching` · `results` · `noResults` · `detectingGps` · `gpsAcquired` ·
`gpsFailed` · `pinMode` · `resolvingAddress` · `addressResolved` · `confirmed`.

**Empty states.**

| Case | Treatment |
|---|---|
| No search entered | Recent locations, then popular localities in the launch city — never a blank field with no starting point |
| No search results | *"We couldn't find that. Try a locality or pincode"* + drop-a-pin option |

**Error states.**

| Failure | Handling |
|---|---|
| Geocoding service down | Map pin still works using raw coordinates + a manual landmark note. Discovery is not blocked on a third-party geocoder. |
| GPS timeout (15 s) | *"Couldn't get your location"* → manual, with GPS retry available |
| Offline | Cached last location + *"You're offline — using your last known area"* |
| Point outside serviceable bounds | Explicit message, `Confirm` disabled. Never a silent failure or an empty result list downstream. |

**Validation.**

- Pincode: exactly 6 digits, numeric, **first digit 1–8** (Indian PIN codes begin 1–8; 0 and 9 are
  invalid). Rejecting these here prevents a confusing empty Discover later.
- A locality must resolve to coordinates before `Confirm` enables.
- The chosen point must fall inside serviceable bounds.
- Display precision must match granted precision: with only approximate permission, show
  locality-level text and say so. Reverse-geocoding coarse coordinates into a confident street
  address is a lie the user will act on.

**Accessibility.** **A draggable map pin is inaccessible to screen readers, so the search-and-confirm
path must be independently sufficient** — the map is an enhancement, never the only route. The map
carries `Semantics(label: 'Map showing selected location: <resolved address>')`, and the pin is
repositionable from the search field, not exclusively by drag. Autocomplete results are a live region
announcing the result count. Search field labelled persistently, `TextInputType.streetAddress`.

---

## 5a.5 Dietary setup — `/dietary-setup`

**Purpose.** Capture a **hard constraint** before showing any results. In India this is religious and
ethical identity, not a taste preference (Phase 1 §3.1).

**User goals.** Guarantee that what the app offers is food they can actually eat.

**Components.** Headline *"So we only show food you can eat"* · four large selectable option cards ·
**Show me everything** (explicit, tertiary) · reassurance *"Change this anytime in Settings"* ·
**Continue**.

**Options — acceptance sets, not labels.** See §5a.12 (A7).

| Option | Accepts |
|---|---|
| Jain | `{jain}` |
| Pure vegetarian | `{pureVeg, jain}` |
| Vegetarian, egg is fine | `{pureVeg, jain, containsEgg}` |
| I eat everything | all four |

**States.** `noSelection` · `selected` · `showAllChosen`. Local only.

**Empty / error states.** None.

**Validation.** Exactly one preset must be chosen — **`Continue` is disabled until then.** This is a
deliberate exception to our bias against blocking CTAs: silently defaulting a religious dietary
constraint is the single worst failure this app could ship. "Show me everything" is one tap away, so
the user is never trapped — only required to *state* the choice rather than inherit it.

**Accessibility.** Cards use **radio semantics** (`Semantics(inMutuallyExclusiveGroup: true, checked:
…)`), not button semantics — a screen reader must announce the selected state and the group
relationship. Selection is conveyed by checkmark **and** border **and** label, never colour alone.
The conventional Indian green-dot / brown-triangle marks always carry a text label: they are not
universally understood and are not accessible. Targets ≥ 48 dp; cards must survive
`textScaleFactor` 2.0 (labels wrap, cards grow — no fixed heights).

---

## 5a.6 Phone entry — `/auth/phone`

**Purpose.** Begin authentication at the point of highest intent, with minimum friction (A4 — the
wall sits at add-to-cart).

**User goals.** Get past this in as few taps as possible, understanding why it is being asked.

**Components.** Back · **context banner** · headline · static `+91` prefix · 10-digit field · Phone
Number Hint trigger · terms consent line · **Continue**.

**The context banner is not decoration.** *"Sign in to reserve your bag"*, carried from the
`redirect` parameter. An auth wall that appears without explanation, mid-intent, is where users
bounce — the banner converts an interruption into a step.

`+91` is rendered as a **static prefix, not a country picker.** V1 is single-country (assumption A3);
a picker with one entry is pure friction. Reintroduced when a second country is.

**States.** `idle` · `hintAvailable` · `valid` · `submitting` · `rateLimited` · `error`.

**Empty states.** None.

**Error states.**

| Failure | Copy direction |
|---|---|
| Network | *"Check your connection"* + retry, number preserved |
| Rate limited | *"Too many attempts. Try again in 4m 30s"* — live countdown, not a bare refusal |
| SMS provider / DLT failure | *"We're having trouble sending codes"* → offer the WhatsApp route immediately rather than making the user guess |
| Number blocked | Support path, no accusatory language |

**Validation.**

- Exactly 10 digits; **first digit 6–9** (Indian mobile numbering). Landlines are rejected here, not
  after a failed SMS.
- Paste sanitisation: strip spaces, hyphens, `+91`, and a leading `0`. Users paste numbers in every
  conceivable format and none of it should be their problem.
- Numeric keyboard; `Continue` disabled until valid; validation on blur and submit, **not per
  keystroke** — an error appearing on digit 3 of 10 is noise.

**Accessibility.** `TextInputType.phone`, `autofillHints: [telephoneNumberNational]`. Persistent
visible label (§C6 — no placeholder-as-label). Errors announced assertively and programmatically
associated with the field. The terms link is a real focusable link, positioned **above** the CTA and
above the fold — consent the user must scroll to find is not consent.

---

## 5a.7 OTP verify — `/auth/otp`

**Purpose.** Verify possession of the number over a channel we know to be lossy and regulated
(Phase 1 §3.5).

**User goals.** Get in without typing anything, and if the SMS never arrives, have another way.

**Components.** Back (to correct the number) · masked number + **Change** · 6-digit code field ·
auto-read status · resend countdown · **Get the code on WhatsApp** · **Get a call instead** ·
**Verify**.

**States.** `awaitingAutofill` · `manualEntry` · `partial` · `complete` · `verifying` · `success` ·
`invalid` · `expired` · `attemptsExhausted` · `resendCooldown` · `resendAvailable`.

**Auto-read.** Android: SMS Retriever API — autofill with **no SMS permission requested**, which
matters because an SMS-read permission prompt is a trust event we should never spend. iOS:
`oneTimeCode` autofill via the keyboard suggestion strip.

**Escalation ladder** — because assuming SMS will arrive is how this screen fails in India:

| Moment | Offer |
|---|---|
| 0–30 s | *"Waiting for SMS…"* |
| 30 s | Resend enabled |
| After 1st resend | **WhatsApp** surfaced |
| After 2nd resend | **Voice call** surfaced |

Code validity: 10 minutes. Auto-submit on the sixth digit.

**Empty states.** None.

**Error states.**

| Failure | Handling |
|---|---|
| Invalid code | Clear field, retain focus, show *"2 attempts left"*. Never a silent rejection. |
| Expired | *"This code expired"* + one-tap new code |
| Attempts exhausted | 15-minute lock with a live countdown and an explanation |
| **Network failure mid-verify** | **Ambiguous — the code may already have been consumed server-side.** Retry with the *same* code; the verification endpoint must be idempotent (Phase 7 contract requirement). Silently issuing a fresh code here would invalidate a code the user has already typed correctly. |

**Validation.** 6 digits, numeric only, auto-submit on completion.

**Accessibility.** `autofillHints: [oneTimeCode]`. **The six-box UI must present as one logical field**
— announced as *"Verification code, 6 digits"*, not traversed as six separate inputs, which is the
single most common accessibility defect in OTP screens. Autofill announces *"Code received,
verifying"*. The resend countdown is announced **politely at 30 s, 10 s, and 0 only** — a per-second
live region is unusable. On error, no shake-only feedback: colour plus text plus announcement, with
the shake suppressed under reduced motion.

---

## 5a.8 Profile setup — `/auth/profile-setup`

**Purpose.** Capture the minimum needed for a merchant to greet the right customer at pickup.

**User goals.** Finish and get back to the bag.

**Components.** Headline *"What should we call you?"* · name field · **Continue**.

**One field, deliberately.** Email, photo, and preferences are all deferred to Account. The user is
mid-reservation with a live cart hold counting down; every field here is friction at the moment of
peak intent and peak abandonment risk.

**States.** `idle` · `valid` · `submitting` · `submitError`.

**Empty / error states.** Network failure → retry with input preserved (§C1).

**Validation.** 2–50 characters. **Unicode letters permitted** — names are not Latin-only, and a
regex of `[A-Za-z ]` would reject a large share of Indian users' actual names. Allows spaces, `.`,
`'`, `-`. Rejects digit-only input and anything URL-shaped. Trimmed on submit.

**Accessibility.** Persistent label, `autofillHints: [name]`,
`textCapitalization: TextCapitalization.words`.

---

## 5a.9 Force update — `/force-update`

**Purpose.** Prevent a client we have declared unsafe from transacting. Outranks every other guard,
including an in-flight payment (§4.3).

**Components.** Illustration · headline · reason in plain language · **Update now** (store deep
link). **No dismiss, no back.**

**States.** `initial` · `openingStore` · `storeUnavailable`.

**Error states.** Store cannot be opened (no Play Store, offline) → show the store URL as selectable
text plus the reason. Still blocked — but the user must not be left with a dead button and no
explanation.

**Accessibility.** Must not read as an unlabelled trap: heading semantics on the headline, focus
starts there, and the reason is announced. A blocking screen a screen-reader user cannot understand
is indistinguishable from a crash.

---

## 5a.10 Maintenance — `/maintenance`

**Components.** Headline · plain-language explanation · **ETA when known** (an unspecified outage
reads as abandonment) · **Retry** · status-page link.

**States.** `initial` · `retrying` · `stillDown`.

**Accessibility.** As §5a.9. Retry is always reachable.

---

## 5a.11 Session expired — `/session-expired`

**Purpose.** Recover from refresh-token failure without alarming the user about their money.

**Components.** Headline *"Please sign in again"* · **reassurance: *"Your orders and reservations are
safe"*** · **Sign in** (preserving the pre-expiry destination per §4.3).

That reassurance line is doing real work. An unexpected sign-out in an app holding a prepaid
reservation reads as *"my order is gone"*, and a user who believes that contacts support before
reading anything else.

**States.** `initial` · `signingIn`.

**Accessibility.** Announced assertively on entry; focus lands on the heading.

---

## 5a.12 Amendment A7 — dietary preference is an acceptance set

**Finding.** Phase 2 modelled `Customer.dietaryPreference` as a single `DietaryEnvelope?`, mirroring
the bag's field. Writing §5a.5 exposed that as a category error.

A **bag has one envelope** — what it contains. A **customer has an acceptance set** — what they will
eat. These are different shapes, and filtering is set membership:

```
visible(bag, customer) ⇔ bag.dietaryEnvelope ∈ customer.acceptedEnvelopes
```

**Why a single enum is wrong, concretely:** Jain food contains no onion or garlic and is a *subset*
of pure vegetarian. A pure-vegetarian user can therefore eat a Jain bag — but under a single-enum
model, `dietaryPreference == pureVeg` filters Jain bags out. We would hide perfectly acceptable
inventory from a large user segment and never see it in any metric, because the bags simply never
appear. Symmetrically, a vegetarian who eats egg has an acceptance set of three envelopes that no
single enum value can express.

**Change.** `Customer.acceptedEnvelopes: Set<DietaryEnvelope>`, populated from one of the four presets
in §5a.5. The preset is what the UI shows and stores for display; the set is what filters.
`?diet=` (§4.5) carries the preset key, keeping URLs readable, and expands to the set at query time.

**Blast radius.** Phase 2 §2.1 `Customer` · §2.3 facet definition · §4.5 URL parameter semantics ·
the Phase 7 discovery query contract. No UI impact — §5a.5 was already designed around presets.

---

## Handed to Phase 6

Design-system requirements this area generates: **radio-style selectable cards** (dietary) ·
**segmented 6-digit code input** · **static-prefix phone field** · **deferred progress indicator**
(400 ms rule) · **context banner** (auth wall) · **blocking full-screen state** template
(force-update / maintenance / session-expired) · **live countdown text** (resend, rate limit) ·
**dietary marks** with mandatory text labels.
