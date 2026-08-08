# Phase 9 — Copy Deck (cross-cutting + money- and safety-critical)

Status: **for review — this is the product's voice** · Conventions: [§C7](05-screen-definitions-index.md) · Machine artifact: `lib/core/l10n/app_en.arb`

## Scope and why it lands now

The implementation log said the ARB deck lands "alongside the first feature that owns real copy." Two
categories don't belong to any single feature and are the highest-risk content in the product, so they
come first:

1. **The error map** — §C5 requires *authored, domain-specific* copy for all 23 Phase 7 error codes.
   It is cross-cutting by definition.
2. **Money and safety copy** — the payment ambiguity screens, the no-refund terms, the refund
   timeline, the food-safety advisory. These are the lines where wrong wording costs money, trust, or
   someone's health.

Deferred to their feature steps: discovery browse copy, engagement, account settings, help content.

---

## Voice

Five rules, derived from §C7 and the Phase 1 design philosophy.

| Rule | Consequence |
|---|---|
| **Plain, short, calm** | No jargon, no exclamation marks in errors, no marketing verve on a payment screen |
| **Never blame the user** | Including where it would be factually accurate (§3.5) |
| **Explain, don't just refuse** | A refusal with a reason is fair; a bare "not allowed" reads as arbitrary |
| **Money is stated honestly, with dates** | Never "processing" without a date (§5d.4) |
| **Premium, not chirpy** | The user is buying discounted surplus food. Over-celebration reads as overcompensation. |

The third rule is the one that shaped the most lines below, and it is the difference between a policy
users accept and one they complain about.

---

## The single most important line in the application

```
Confirming your payment
Please don't pay again. We're checking with your bank.
Your money is safe.
```

Double payment is the top user fear and the top support cost on Indian UPI flows (§3.6), and the
instinct in an ambiguous state is to retry. So:

- It is an **instruction**, not reassurance. "We're verifying your transaction" invites a retry; "please
  don't pay again" does not.
- "**with your bank**" names an authority the user trusts more than us.
- It is announced **assertively** to screen readers (§5c.6) — a polite live region would queue behind
  the headline and could be missed entirely.

---

## Contested lines, with rationale

### The no-show term (§3.5 obligation 1, shown at checkout)

> **If you don't collect it, you won't get a refund** — the shop sets this bag aside for you and can't
> sell it to anyone else.

The clause after the dash is doing all the work. Without it this is a punitive term the user discovers
at the worst moment; with it, it is a fair one they can reason about. §3.5 requires this term be visible
at checkout in plain language precisely so that declining a refund later is defensible.

### The no-show aftermath (§3.5, the hardest copy in the product)

> **This pickup window has closed**
> The window closed at 10:00 pm. Because the shop had set this bag aside, we can't refund it — but if
> you were there and couldn't collect, tell us.

Rejected: *"You missed this pickup."* Accurate, and it breaks the §3.8 rule against blaming the user.
The user already knows they missed it; saying so converts a lapsed order into a lost customer.

The final clause matters as much as the tone: §3.3 documents several merchant-side failures that
produce this same state, so the copy must not assume fault it cannot verify.

### Merchant cancellation (§3.4)

> **Your bag isn't available**
> Sweet Crumb had to cancel. This isn't your fault — we've already started your full refund of ₹132.

Leads with the **refund**, not the cancellation. A user who may be standing outside the shop needs the
money answer first. "This isn't your fault" is explicit because an unexplained cancellation reads as
something the user did wrong. The merchant is named without being blamed — they are the scarce side of
this marketplace.

### The purchase cap (A9)

> **You can reserve up to 2 of these**
> This keeps enough for other people. You have 1 left on this bag.

The middle sentence converts an arbitrary-seeming limit into a fairness rule. Without it, a cap reads as
a broken app.

### The cancellation cutoff (A15)

> **Too late to cancel**
> Free cancellation ended at 7:00 pm. The shop has already set this bag aside.

Same pattern: the reason is what makes the refusal acceptable.

### Server errors

> **Something went wrong on our side**
> This isn't your fault. Please try again.

"On our side" and "not your fault" are both deliberate. Users blame themselves for 500s, then stop
trying.

### Hold expiry (§5c.1)

> **Your hold expired**
> We held this bag for 9 minutes. Tap to hold it again — it may still be available.

"**may** still be available" rather than "hold it again" alone. Promising availability we have not
revalidated (R2) would produce a second failure immediately after the first.

### The food-safety advisory (A16)

> **Please don't eat it**
> If you haven't eaten this food, stop now. Tell us what happened and we'll act quickly.

Shown **before** the report form. The next few minutes matter more than our ticket. Blunt on purpose —
this is the one place in the product where hedged copy could cause harm.

### Session expiry (§5a.11)

> **Please sign in again**
> Your orders and reservations are safe.

The second line is load-bearing. An unexpected sign-out in an app holding a prepaid reservation reads as
*"my order is gone"*, and that user contacts support before reading anything else.

### Cold-start payment resume (A3)

> Picking up where you left off.

Under A3 a user can be dropped onto a payment screen they did not navigate to, for a payment they may
not remember starting. Unexplained, that reads as a fraudulent charge attempt.

### Charge status (A13) — two variants, never a guess

| `chargeState` | Copy |
|---|---|
| `notCharged` | You haven't been charged. |
| `uncertain` | If any amount was debited, it will be returned to your account within 3–7 working days. |

Defaulting to the reassuring variant when unsure is tempting and wrong: a user told they were not
charged who then sees a debit escalates to their bank and to a public review. A user told a refund may
be coming who sees nothing debited has lost nothing.

### Refund timeline (§5d.4)

> Usually by 2 Aug — 3 to 7 working days

Never "processing" alone. An open-ended wait is what converts a waiting customer into one who believes
they have been robbed. Phase 1 §3.4 committed to stating this reality upfront; this is where it is kept.

### Failed refund (§3.4)

> **This refund didn't complete**
> Our team is on it and will contact you by 29 July. You don't need to do anything.

Proactive by design. A failed refund that waits for a complaint is a lost customer and a public review.

### Representative image (§5b.9)

> Picture is an example. What's inside changes daily.

Plain rather than legalistic. An appealing photo of food that is not in the bag, unmarked, is a
misleading commercial representation — and more immediately, the fastest route to one-star reviews
saying *"not what was in the picture."*

### Zero-result states (A10) — three causes, three remedies

| State | Copy | Action |
|---|---|---|
| No coverage | **We're not live in Indiranagar yet** — Tell us you're here and we'll let you know when we launch. | Notify me here |
| No supply now | **No bags in Indiranagar right now** — Shops here usually list between 7 and 10 pm. | Watch shops |
| Over-filtered | **No bags match your filters** | Clear filters |

Three distinct messages because the remedies are opposite. One shared "No results" would hand the user
the wrong lever.

### OTP errors (§5a.7)

Rejected throughout: "Invalid OTP", "Authentication failed", "Please enter a valid OTP".

> **That code isn't right** — 2 attempts left.
> **That code expired** — Codes last 10 minutes. Get a new one.
> **We couldn't send an SMS** — Try WhatsApp instead.

Attempt counts are shown because a silent rejection leaves the user unable to judge whether to retry or
start over. The SMS failure immediately offers the alternative channel rather than making the user guess
that one exists — the TRAI DLT reality (Phase 1 §3.5) makes this a routine path, not an edge case.

---

## Terms requiring your sign-off

Three lines state commercial policy and are rendered from `policyValues` (A19), so they change in
config rather than in code:

| Line | Depends on |
|---|---|
| "Free cancellation until {time}" | **A15 — still unsigned** |
| "you won't get a refund" (no-show) | `noShowRefundPolicy: none` |
| "3 to 7 working days" | `refundSlaWorkingDays` |

`{appName}` appears in the pickup instruction (*"Ask staff for a {appName} pickup"*) and is blocked on
brand naming.

---

## Deferred

Discovery browse copy, engagement, account and settings, help topics, legal document bodies. Each lands
with its feature in the Phase 8 §8.12 sequence.

Legal bodies are authored by counsel, not here — but they must render against the same `policyValues`
as the lines above (A19), or the three copies of a commercial term will diverge.
