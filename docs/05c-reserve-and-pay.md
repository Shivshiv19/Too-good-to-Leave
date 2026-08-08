# Phase 5c — Screen Definitions: Reserve & Pay

Status: for approval · Conventions: [05-index](05-screen-definitions-index.md) · Routes: [Phase 4 §4.2](04-navigation-flow.md) · Journeys: [Phase 3 §3.6](03-user-journeys.md)

The highest-risk area in the application. Every screen here can lose a user's money, and two of them
can lose it invisibly.

**Surface reconciliation.** Phase 2 §2.4 listed 7 destinations for this area. It is now **9**:
`/checkout/verifying` became a distinct route in Phase 4 §4.2 (it needs its own back behaviour, and it
is the A3 cold-start resume target), and `/checkout/notify-primer/:orderId` was created by A5.

> Amendments: **A11** (§5c.1) · **A12** (§5c.5) · **A13** (§5c.7).

---

## Rules enforced at the screen level

| Rule | Where it bites in this area |
|---|---|
| **R1** — money never computed on the client | Quantity changes trigger a **server re-quote**, not local multiplication (A11). No total is ever rendered from client arithmetic, not even transiently. |
| **R2** — availability never trusted from cache at a mutation boundary | Hard revalidation on hold creation and again on order creation. |
| **R3** — payment outcome never determined by a client callback | §5c.5 and §5c.6 exist entirely to honour this. |
| **A2** — hold must not expire during payment | The countdown **freezes** once payment enters `pending`; the UI must reflect that rather than continuing to tick toward a deadline that no longer applies. |
| **§3.5 obligation 1** | The no-refund-on-no-show term appears in plain language adjacent to the pay CTA (§5c.2), not in Terms. |

### Area decisions

| # | Decision | Rationale |
|---|---|---|
| **D-c1** | **We never render a card form.** Card and net-banking entry is delegated entirely to the gateway's own PCI-compliant flow. | RBI card-on-file tokenisation means we cannot store card numbers anyway. Rendering our own form would drag the app into PCI-DSS scope for zero product benefit, and would put us in the business of securing card data we have no reason to touch. |
| **D-c2** | **The notification primer is on-path, not a detour** — auto-advanced to after confirmation, and **skipped entirely** when permission is already granted or has been permanently denied. | Re-asking a permanently denied permission is a no-op that costs a screen. Making the primer a side-trip off the confirmation screen would mean the users most likely to skip it are the ones who most need pickup reminders. |
| **D-c3** | **No cancel button on `/checkout/processing`** — but the screen is bounded to 60 s (A12). | A cancel there manufactures the orphan payment we are trying to prevent, because no server-side record yet exists to reconcile against. A bounded wait is honest; an unbounded trap would not be. |
| **D-c4** | **No confirmation dialog before payment.** The CTA states the amount; subtext sets the app-switch expectation. | A dialog adds a tap without adding comprehension. What the user actually needs is to know the amount and that they are about to leave the app — both belong on the button, not behind it. |

---

## 5c.1 Cart — `/checkout?bagId=<id>`

**Purpose.** Confirm what is being reserved, show the true all-inclusive price, and start the hold
clock.

**User goals.** Check the total, confirm when and where to collect, reach payment.

**Components.** Back (retains hold, §4.7) · **hold countdown banner**, prominent and persistent ·
merchant header with distance and landmark · bag line with dietary label, capped quantity stepper
(D-b6), unit price · **pickup window block** · server `PriceBreakdown` · **all-inclusive total
callout** · cancellation-policy summary with link · **Continue to payment**.

The pickup window is given real visual weight here, not a footnote. It is the physical commitment the
user is about to prepay for, and the §3.5 no-show journey begins with a user who never registered it.

**States.** `creatingHold` · `holdActive` · **`requoting`** · `holdExpiring` (< 2 min, escalated
treatment) · `holdExpired` · `holdFrozen` (A2 — payment in flight) · `revalidating` · `error` ·
`offline`.

**Empty states.** None. The cart cannot be empty; arriving without a valid bag is a redirect, not a
state.

**Error states.**

| Failure | Treatment |
|---|---|
| Hold creation → 409 sold out | Domain-specific (§C5): *"This bag just went"* + alternatives at this merchant and nearby |
| Hold creation → cap exceeded (A9) | *"You can reserve up to 2 of these"* — stepper reflects the true remaining allowance |
| **Hold expired** | Clear state + **one-tap re-reserve with revalidation.** Required by §C6 / WCAG 2.2.1: nothing lost to a timer may be unrecoverable. |
| Re-quote fails | **Retain the last valid breakdown, disable Continue, offer retry.** Never present a stale total as current, and never fall back to client arithmetic. |
| Different-merchant bag while a hold exists | Confirm dialog — *"Replace your reservation at Sweet Crumb?"* (assumption A6, single-merchant carts) |
| Offline | Mutation blocked (§C3); the hold survives server-side until its TTL |

**Validation.** Quantity within `min(available, 2)`. Total originates from the server, always (R1).

**Accessibility.**

- **Countdown is a polite live region announced at 5 min, 2 min, 1 min, and 30 s only** — never per
  second, which is unusable. Expiry is announced assertively.
- Total announced with its inclusivity stated: *"Total to pay, ₹132, including all taxes and fees."*
- The breakdown is a **semantic label–value list**, not a visual two-column layout. A right-aligned
  column of bare numbers is meaningless to a screen reader.
- The countdown is informational only; expiry is one tap from recovery (§C6).

### Amendment A11 — quantity changes require a server re-quote

**Finding.** Rule R1 forbids client-side money arithmetic, but the obvious cart implementation
multiplies unit price by stepper value to show a live total. That is exactly the prohibited
computation, and under the unresolved GST §9(5) question (Phase 1 §3.3) it is also *wrong* — platform
fee and tax lines are not necessarily linear in quantity.

**Change.** The stepper is debounced (~400 ms) and issues a **server re-quote**. During flight the
total enters a `requoting` treatment; `Continue` is disabled until a fresh authoritative breakdown
returns. No locally-computed total is ever displayed, not even optimistically.

**Phase 7 effect.** A `POST /checkout/quote` endpoint distinct from hold creation, callable repeatedly
without side effects on the hold.

**UX cost, accepted.** A brief re-quote latency on stepper change. The alternative is a total that
disagrees with what we charge — which is the one defect in a payments flow that is never recoverable
by an apology.

---

## 5c.2 Review & pay — `/checkout/pay`

**Purpose.** Final review, method selection, and the binding commitment.

**User goals.** Confirm the amount, choose how to pay, understand what they are agreeing to.

**Components.** Hold countdown (continuing) · compact order summary (merchant, bag, quantity, pickup
window) · payment method row → §5c.3, **UPI pre-selected** (Phase 1 mandate) · last-used UPI app shown ·
server `PriceBreakdown` · **terms block adjacent to the CTA** · **`Pay ₹132`** with subtext *"You'll be
taken to your UPI app."*

**The terms block, in plain language, above the fold, next to the button:** the pickup window
commitment · **no refund if not collected** · the cancellation window. This is §3.5 obligation 1
discharged. Burying it in Terms and then declining a refund is precisely the sequence that produces a
justified complaint, and it would make the §3.5 policy indefensible however correct it is.

**States.** `idle` · `methodSelected` · `submitting` (creating order) · `redirecting` · `error`.

**Error states.**

| Failure | Treatment |
|---|---|
| Order creation → sold out | 409 domain copy + alternatives |
| Order creation → hold expired | Recoverable per §5c.1 |
| Payment initiation fails (gateway down) | *"Couldn't reach payment"* + one-tap method switch. A single rail's outage must not end the sale. |
| No UPI app installed | Detected **before** offering UPI, via intent resolution — never present a rail that cannot launch |

**Validation.** A method must be selected. Terms are displayed, not checkbox-gated — continuing
constitutes acceptance, which is acceptable only because the terms are visible without scrolling
(same standard as §5a.6).

**Accessibility.** **The CTA label carries the amount.** A button announced only as *"Pay"* immediately
before debiting an account is an unacceptable ambiguity for a screen-reader user. Terms are real text
in the semantic tree, never rasterised. Method changes are announced.

---

## 5c.3 Payment method sheet — bottom sheet, no route

**Purpose.** Choose the rail.

**Components.** UPI (**Recommended**) · Cards · Net banking · Wallets. UPI expands to installed apps
or *Pay by UPI ID* (collect request).

**States.** `detectingApps` · `appsDetected` · `noAppsFound` · `idle`.

**Error states.** A rail disabled by gateway configuration is shown **disabled with its reason**, not
silently removed — a user hunting for a missing option assumes the app is broken.

**Validation.** None.

**Accessibility.** Radio semantics. **"Recommended" is text, not a colour badge alone.** Disabled
options announce why they are disabled.

**Security (D-c1).** Selecting Cards or Net banking hands off to the gateway's own flow. We render no
card fields, hold no PAN, and stay outside PCI-DSS scope.

---

## 5c.4 UPI app chooser — bottom sheet, no route

**Purpose.** Choose which UPI app receives the hand-off.

**Components.** Installed apps with icon **and name** · *Pay by UPI ID* fallback · *Remember my choice*.

**States.** `idle` · `launching` · `launchFailed`.

**Error states.** Launch fails because the app was removed between detection and tap → re-detect and
re-present, rather than failing the payment.

**Accessibility.** App names are text — an icon grid alone is inaccessible. The remember toggle is
labelled with its effect.

---

## 5c.5 Processing — `/checkout/processing`

**Purpose.** Carry the user through gateway initiation and the UPI app-switch with **no exit**
(§4.7), while remaining reassuring rather than frightening.

**User goals.** Know that something is happening and that it is safe.

**Components.** Amount and merchant · status text · indeterminate progress · **explicit explanation of
why there is no back button** · after 15 s, *"Still working — please don't close the app."*

**States.** `initiating` · `awaitingAppSwitch` · `appSwitched` (our app backgrounded) · `returned` ·
`slow` (> 15 s) · `timeout` (60 s → auto-transition to §5c.6).

**Error states.** Gateway initiation fails **before** app-switch → redirect back to `/checkout/pay`
with a method-switch prompt. This is the only exit, and it is a redirect rather than a back
navigation.

**Validation.** None.

**Accessibility.** `canPop: false` must be reported **accurately** for Android 14 predictive back
(§4.7). **The absence of a back affordance must be explained in text** — an unexplained trap is
indistinguishable from a freeze, and a screen-reader user has no visual cue that the block is
intentional. Under reduced motion the spinner is replaced by a textual status progression, so
progress remains perceivable.

### Amendment A12 — `/checkout/processing` is bounded to 60 seconds

**Finding.** Phase 4 §4.7 blocks back on this screen, correctly. Reviewing it as a *screen* rather
than a route exposed that the block was unbounded — a user whose gateway call hangs would be held on a
no-exit screen indefinitely. That is a trap, and no amount of correct reasoning about orphan payments
justifies one.

**Change.** After 60 s the screen **auto-transitions to `/checkout/verifying`**, which is exitable and
resolvable by push. The maximum time a user can be unable to leave is therefore bounded and short.

This also resolves the objection to D-c3 cleanly: we are not refusing the user an exit, we are
deferring it to the first moment we have a server-side record worth reconciling against.

---

## 5c.6 Verifying — `/checkout/verifying?orderId=`

**Purpose.** Resolve payment ambiguity **without the user paying twice.** The single most consequential
screen in the application (§3.6).

**User goals.** Find out whether the money left their account and whether the bag is theirs — and be
told, unambiguously, not to try again.

**Components.**

| Element | Content |
|---|---|
| Headline | *"Confirming your payment"* |
| **Primary instruction** | **"Please don't pay again. We're checking with your bank."** |
| Context | Amount · merchant |
| Reassurance | *"Your money is safe."* |
| After ~30 s | *"Taking longer than usual. We'll notify you within X minutes."* + **Notify me** (leave safely) |
| Cold-start entry (A3) | Additional line: *"Picking up where you left off"* |

**That instruction is the most important copy in the app.** Double payment is the top user fear and
the top support cost on Indian UPI flows, and the instinct in an ambiguous state is to retry. It is
stated as an instruction, not buried in reassurance.

**The cold-start line is not a nicety.** Under A3 a user can be dropped here on launch, on a payment
screen they did not navigate to, for a payment they may not remember initiating. Without an
explanation, that screen reads as a fraudulent charge attempt.

**Polling.** Exponential backoff — 2 s, 3 s, 5 s, 8 s, 13 s, then 15 s intervals, capped at 5 minutes,
after which resolution arrives by push.

**States.** `verifying` · `slow` (> 30 s) · `resolvedCaptured` → §5c.8 · `resolvedFailed` → §5c.7 ·
**`resolvedHoldCollision`** (A2) · `leftPending`.

**`resolvedHoldCollision`** — payment captured, but the bag went to someone else. Authored, never
generic: *"Your payment went through, but this bag was taken. We've started a full refund of ₹132."* →
routes to `/orders/:id/refund`. A2 makes this rare by design; it must still be designed for.

**Error states.** Verification endpoint unreachable → *"We can't reach our servers. Your payment is
safe and we'll confirm it shortly."* + retry + notify-me. **Nothing on this screen may ever imply the
money is lost or unaccounted for**, even when we genuinely do not yet know its state.

**Validation.** None.

**Accessibility.** **The don't-pay-again instruction is announced assertively on entry** — a polite
live region would queue behind the headline and could be missed entirely, and this is the one message
in the app that must not be missed. Status transitions are announced. `canPop: true`, with the
confirmation handled in `onPopInvokedWithResult` (§4.7), so predictive back stays truthful.

---

## 5c.7 Payment failed — `/checkout/failed?orderId=`

**Purpose.** Recover the sale without leaving any doubt about the user's money.

**Components.** Headline *"Payment didn't go through"* · **charge-status statement (A13)** ·
plain-language reason · **hold status** · retry with same method · try another method · back to bag.

**Hold status is the difference between a recovered sale and a lost one:** if the hold is alive,
*"Your bag is still held for 4:32"* + Retry; if expired, a one-tap re-reserve.

**States.** `notCharged` · `chargeUncertain` · `holdAlive` · `holdExpired` · `retrying`.

**Error states.** This is the error screen. Gateway reason codes are **mapped to authored copy** —
insufficient funds, declined by bank, cancelled, timed out. Raw codes never surface (§C5).

**Validation.** None.

**Accessibility.** The charge-status statement is announced **assertively** — it is the first thing the
user needs. Retry CTA carries the amount.

### Amendment A13 — charge status is server-determined, never inferred

**Finding.** The natural copy for a failed payment is *"You haven't been charged."* But a client
reaching this screen after a UPI timeout **does not know that**, and asserting it when a debit
actually occurred is the most damaging false statement this app could make.

**Change.** Phase 7 must return a definitive `chargeState` on the failure response, and this screen
renders one of two authored variants — never a guess:

| `chargeState` | Copy |
|---|---|
| `notCharged` (server-confirmed) | *"You haven't been charged."* |
| `uncertain` | *"If any amount was debited, it will be returned to your account within 5–7 working days."* |

Defaulting to the reassuring variant when unsure is the tempting choice and the wrong one: a user who
is told they were not charged, then sees a debit, escalates to their bank and to a public review. A
user told a refund may be coming, who then sees nothing debited, has lost nothing.

---

## 5c.8 Reservation confirmed — `/checkout/confirmed/:orderId`

**Purpose.** Deliver relief, then orient the user toward the pickup they have just committed to.

**Components.** Calm success affirmation · **order code** (`SV-7K2M`) · **pickup window — the most
important information on the screen** · merchant, landmark, **Directions** · **Add to calendar** ·
**View pickup details** → `/orders/:id/pickup` · Back to Discover.

**Add to calendar** is a small feature with outsized value in a time-boxed pickup product: it is the
cheapest available intervention against the §3.5 no-show journey, which is the one journey with no
good outcome for anyone.

Tone: calm and premium per the design philosophy, not a confetti burst. The user spent money on
discounted surplus food; over-celebration reads as overcompensation.

**States.** `loaded` · `loading` (brief, when arriving from push).

**Error states.** Order fetch fails → **still show success**, using the order code from local state,
and degrade the rest gracefully. An error screen immediately after a successful payment is the worst
possible moment for one, and the payment's success is not contingent on this fetch.

**Validation.** None.

**Accessibility.** Success announced assertively. **Order code announced character by character** — it
is an identifier the user may need to read aloud at a counter, and hearing it as a word is useless.
Pickup window announced with day context: *"Today, 8 to 10 pm."* Under reduced motion, a static
success mark with text rather than an animated check.

**Onward routing (D-c2).** If notification permission is not yet granted and not permanently denied →
auto-advance to §5c.9. Otherwise → straight to pickup details.

---

## 5c.9 Notification primer — `/checkout/notify-primer/:orderId`

**Purpose.** Request notification permission at the moment of peak consent (D2) — the user now has
money committed and a genuine need for a reminder.

**Components.** Headline *"We'll remind you to collect"* · three value lines (window opening · closing
soon · changes from the merchant) · **Turn on reminders** → OS request · **Not now**.

**States.** `initial` · `requesting` · `granted` · `denied`.

**Error states.** Denied → **must not dead-end.** Proceed to pickup details with a plain explanation
that in-app reminders and the Orders badge will be used instead, plus where to enable notifications
later. A user who declines must still be able to complete a pickup (§3.8 theme 2).

**Validation.** None.

**Accessibility.** *"Not now"* carries genuine visual weight — same principle as the manual-location
option in §5a.3, and for the same reason. Both CTAs ≥ 48 dp. The OS dialog opening is announced, since
screen-reader focus leaves the app.

---

## Handed to Phase 6

New design-system requirements: **hold countdown banner** at three urgency levels plus a frozen state
(A2) · **price breakdown list** with semantic label–value pairing · **all-inclusive total callout** ·
**terms block** adjacent to a CTA · **amount-bearing CTA** · **no-exit processing layout** with textual
progress · **assertive-instruction block** (the don't-pay-again treatment) · **charge-status
statement** variants · **order code display** (monospace, character-readable) · **calm success
affirmation** with reduced-motion variant · **permission primer** template (shared with §5a.3).
