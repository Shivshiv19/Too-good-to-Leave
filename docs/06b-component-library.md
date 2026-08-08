# Phase 6b — Component Library

Status: for approval · Foundations: [06 Design System](06-design-system.md) · Screens: [05a](05a-onboarding-auth.md)–[05f](05f-account.md)

41 components, accumulated from the six *"handed to Phase 6"* sections. Foundations and the eight
risk-carrying domain components are specified in full; the remainder are inventoried with their anatomy,
variants, and the accessibility requirement that constrains them.

Every component: consumes semantic tokens only (§6.1) · has a reduced-motion variant where it animates ·
is verified at `textScaleFactor` 2.0 and in both themes (§C8).

---

## 6b.1 Foundations

### Button

| Aspect | Spec |
|---|---|
| Variants | `primary` (filled) · `secondary` (outlined) · `tertiary` (text) · `destructive` |
| States | default · pressed · disabled · **loading** |
| Sizes | `large` 52 dp (primary CTAs) · `medium` 44 dp · `small` 36 dp — small never used for a primary action |
| Loading | In-place spinner replacing the label; **width does not change** (a reflowing button under the user's thumb causes mis-taps) |
| Disabled | Reduced opacity **plus** a reason available as text — never a silently dead button (§5e.3) |
| **Amount variant** | Renders `Pay ₹132`; the amount is part of the semantic label (§5c.2) |
| **Outcome variant** | For destructive money actions: `Cancel reservation — no refund` (§5d.5) |
| A11y | Label states the action, not the location. 48 dp target regardless of visual height. Loading announces politely. |

### Text field

Persistent visible label **always** — placeholder-as-label is prohibited (§C6). Anatomy: label ·
prefix/suffix · input · helper · error · counter.

Variants: `text` · `phone` (static `+91` prefix, §5a.6) · `email` · `multiline` · `search` ·
`segmentedCode` (below).

Validation timing: **on blur and submit, never per keystroke** (§5a.6). Error text is programmatically
associated and announced assertively. Counter is a polite live region.

### Segmented code input

Six boxes that **present as one logical field** — the most commonly botched accessibility detail in OTP
UIs (§5a.7). One `Semantics` node labelled *"Verification code, 6 digits"*; the boxes are visual only.
Auto-advance, auto-submit on completion, paste distributes across boxes, `oneTimeCode` autofill.

### Selectable card

Radio or checkbox semantics — **never button semantics** (§5a.5). Selection conveyed by checkmark **and**
border **and** label; never colour alone. Grows with content; no fixed height. Used for dietary presets,
payment methods, issue types, sort options.

### Chip

| Variant | Use |
|---|---|
| `facet` | Filter state with active indicator and count (§5b.1) |
| `tag` | Toggle semantics, review tags (§5e.3) |
| `status` | Read-only, icon + text |

Never colour-only for active state. Horizontally scrollable rows expose their overflow (a partially
visible chip, not a hard clip).

### Switch row / always-on row

Two distinct components, deliberately.

`switchRow` — label · optional description · switch. Optimistic with rollback.

**`alwaysOnRow`** — label · reason · a lock affordance. **Visually and semantically distinct from a
disabled switch** (§5f.4). A greyed-out switch reads as a bug and invites repeated tapping; this reads as
a policy, and announces *"Pickup reminders, always on"*.

### Dialog

Variants: `standard` · `destructive`.

Traps focus, restores on dismiss. **The consequence sentence is announced before the buttons**
(§5d.5, §5f.11). Destructive confirmations use outcome-bearing labels — never a bare *Confirm* on a money
or deletion action. Max width 400 dp; scrolls internally at scale 2.0.

### Bottom sheet

Traps focus, restores on dismiss. Drag handle plus an explicit close. **Scrollable content with a fixed
footer action** — the failure mode is a fixed-height sheet that clips at `textScaleFactor` 2.0 (§5b.4).
Max height 90% viewport.

### Snackbar

Variants: `info` · `success` · `error` · **`undo`** (§5e.2). Above the sticky action bar and the bottom
nav, never over them. Undo persists 5 s minimum, and **is never the only path to recovery** — WCAG 2.2.1
(§C6).

### Banner

Persistent, non-blocking, positioned below the app bar.

| Variant | Source |
|---|---|
| `offline` | §C3 |
| `stale` — *"as of 7:42 pm"* | §2.5 |
| `permissionState` | §5e.1, §5f.4 |
| **`advisory`** | A16 — visually distinct from both error and info; carries a safety instruction, not a status |

### Skeleton

Shape primitives (`box`, `text`, `circle`) composed into per-screen skeletons that **match final layout
geometry** (§C1) — a skeleton whose shape differs from the loaded content produces the content jump it
exists to prevent. Shimmer becomes a static placeholder under reduced motion (§6.6).

### Progress indicator

**Deferred by 400 ms** (§C1) — the rule is enforced inside the component, not left to call sites.
Variants: `circularIndeterminate` · `linearDeterminate` · `inlineButton`. Under reduced motion, a
textual status progression replaces the spinner (§5c.5).

### Empty state

Slots: illustration · headline · body · primary action · secondary action. Enforces the §C4 contract —
**what, why, one next action**. Three layouts from A10 (no coverage · no supply now · over-filtered).
State and reason announced on entry.

### Blocking full-screen state

Force-update · maintenance · session-expired (§5a.9–11). No dismiss, no back. Focus starts on the
heading with `header` semantics — a blocking screen a screen-reader user cannot parse is
indistinguishable from a crash.

---

## 6b.2 Domain components — specified in full

These eight carry correctness or trust risk. The rest are inventoried in §6b.3.

### Bag card

The most-repeated composite in the app (§5b.1). Anatomy: thumbnail · merchant name + category · bag
title · **dietary mark + label** · price block · distance · pickup window · scarcity cue · rating.

Variants: `list` (full) · `compact` (alternatives lists, merchant profile) · `skeleton`.

**One merged semantic node** with a front-loaded label ordered by what decides the tap:
> *"Bakery Surprise Bag, Sweet Crumb. Pure vegetarian. ₹120, was ₹350, 65% off. 1.2 km. Collect 8 to 10 pm.
> Only a few left."*

Images: WebP at served resolution, cached, labelled placeholder on failure — never a broken-image glyph.

### Price display

Anatomy: current price (`priceLarge`/`priceMedium`) · struck retail value · discount % badge.

**The struck value must be announced as *"was ₹350"***, never as a bare number — read without the
qualifier it sounds like the price (§5b.1). Strikethrough is decorative; the semantics carry the meaning.
`en_IN` grouping throughout (§C7).

### Price breakdown

**A semantic label–value list, not a visual two-column layout** (§5c.1). A right-aligned column of bare
numbers is meaningless to a screen reader.

Rows: bag subtotal · platform fee · tax lines (server-supplied labels, §2.1) · discount · **all-inclusive
total callout**. States: `loaded` · **`requoting`** (A11 — total in a pending treatment, prior value
retained, never client-computed) · `error` (last valid breakdown retained, action disabled).

Total announced with its inclusivity: *"Total to pay, ₹132, including all taxes and fees."*

### Countdown

`countdown` type role with **tabular figures** (§6.3.2) so it does not jitter as it ticks.

| State | Treatment | Announce at |
|---|---|---|
| `upcoming` | neutral | — |
| `openNow` | success (§6.2.7) | on transition |
| `closingSoon` | critical | 30 · 10 · 5 min |
| **`frozen`** | neutral, static, explanatory label | on entry (A2 — payment in flight) |

Cart-hold variant announces at 5 min · 2 min · 1 min · 30 s (§5c.1). **Polite, at thresholds only** —
a per-second live region is unusable. Expiry announces assertively, and **is always recoverable in one
tap** (WCAG 2.2.1).

### QR display block

**The highest-stakes component in the library** (§5d.3, A1, A21).

| Rule | Reason |
|---|---|
| **Always dark-on-light, in both themes** | Many scanners fail on inverted QR (A21) |
| **Minimum size floor; page scrolls rather than shrinking** | An unscannable QR is total screen failure |
| Defined quiet zone | Scanner requirement |
| Brightness maximised on entry, restored on exit, **with a manual toggle** | Shop lighting (§3.3); forced brightness is an accessibility problem for photosensitive users |
| Three token layers rendered in priority order | A1: rotating → offline window token → fallback code |
| Offline indicator when serving the cached token | Honest and reassuring, not an error |
| A11y | A QR is inaccessible by nature. **The paired code display is the accessible equivalent and must be independently sufficient.** |

### Mono code display

Fallback code and order code (§5d.3, §5c.8). `codeMono` with `0.15em` letter-spacing — transcribed by a
stranger at arm's length.

**Announced character by character.** Hearing `SV-7K2M` as a word, or an FSSAI licence number as a
cardinal, makes it unusable. Long-press to copy; copy confirms via snackbar.

### Order status chip

One treatment per `OrderStatus` (§2.2). **Icon + text, never colour alone** (§C6).

| Status | Feedback role |
|---|---|
| `pendingPayment` · `readyForPickup` | info |
| `confirmed` | success, low emphasis |
| `collected` | success |
| `paymentFailed` | critical |
| `cancelledByMerchant` · `cancelledByCustomer` | neutral |
| `expiredUncollected` | neutral, de-emphasised — **not critical.** §3.5 forbids blaming the user, and a red chip on their own history does exactly that. |

### Timeline

Three-step refund progress (§5d.4). Per-step states: `pending` · `active` · `complete` · `failed`.

**An ordered list announcing position and state** — *"Step 2 of 3, sent to your bank, completed 26 July."*
Each step carries a timestamp or an expected date; **no step ever renders without one** (§5d.4 — "never
the word processing without a date").

---

## 6b.3 Domain component inventory

| Component | Anatomy / variants | Constraining requirement | Source |
|---|---|---|---|
| **Dietary mark** | Veg · non-veg · egg · Jain | Fixed non-themeable colours; light chip in dark mode; **text label mandatory** | A22 |
| **Scarcity cue** | `qualitative` · `exact` | Qualitative in cached contexts, exact only after fresh fetch | A8 |
| **Urgency section header** | Collect now · Later today · Tomorrow | `header` semantics | §5b.1 |
| **Hold countdown banner** | 3 urgency levels + frozen | Persists across Discover; frozen state during payment | §5c.1, A2 |
| **Trust block** | FSSAI number · validity · verified badge | Licence number announced digit by digit | §5b.8 |
| **Legal disclosure block** | Legal name · grievance contact | Required by CP E-comm Rules 2020; appears on profile and order | §5b.8, §5d.2 |
| **Rating display** | Stars · count · histogram | *"4.3 out of 5, 128 reviews"* — never a bare number. **Histogram needs a text equivalent** | §5b.8, §5b.11 |
| **Star rating input** | 5 discrete buttons | **Not a drag target** — ≥48 dp each; *"Rate 3 of 5 stars"* | §5e.3 |
| **Photo carousel** | Images · position indicator · arrows | **Navigable without swipe**; announces *"Photo 2 of 4"* | §5b.8 |
| **Sticky action bar** | Stepper + primary CTA | Respects bottom safe area and nav bar | §5b.9 |
| **Quantity stepper** | −/value/+ | Cap announced when reached; triggers server re-quote | §5b.9, A11 |
| **Status banner** | One per order status | Announced assertively on entry | §5d.2 |
| **Hero pickup card** | Countdown · directions · show-code | Primary action labelled with effect | §5d.1 |
| **Availability badge** | Bags now · lists ~8 pm · closed | Text, not colour | §5e.2 |
| **Saved merchant card** | Photo · name · availability · bell toggle | Bell announces state; unsave in overflow, **not swipe-only** | §5e.2 |
| **Notification list item** | Type icon · title · body · time · unread | Unread in the label, not a dot alone; **absolute time in semantics** | §5e.1 |
| **Conditional tag set** | Positive set · negative set | Switches on rating | §5e.3 |
| **Escalation bridge** | Prominent secondary action | Visually distinct from both error and CTA | §5e.3, A16 |
| **Assertive instruction block** | Icon · instruction · reassurance | **Announced assertively on entry** — the don't-pay-again treatment | §5c.6 |
| **Charge-status statement** | Two server-determined variants | Never inferred client-side | A13 |
| **Context banner** | Reason for the auth wall | Carries `redirect` intent | §5a.6 |
| **Permission primer** | Illustration · value lines · allow · **peer-weight decline** | Decline must not be de-emphasised | §5a.3, §5c.9 |
| **Profile header** | Avatar · name · masked phone · **anonymous variant** | Gated items labelled as such | §5f.1, A18 |
| **Grouped settings list** | Section headings · rows · gated treatment | Group headings are semantic headings | §5f.1 |
| **Blocker list** | Items with resolution links | Announced on entry | §5f.11 |
| **Document renderer** | Restricted markdown subset | **No arbitrary HTML**; heading navigation; scales to 2.0 | §5f.7, §5f.9 |
| **Photo attachment row** | Thumbnails · per-item remove · add | Individually labelled removes; EXIF stripped on pick | §5d.6 |
| **Map pin / cluster** | Merchant pin · cluster · selected | Labelled, but the list is the accessible equivalent | §5b.2 |
| **Storage size display** | Label · computed size | Announced | §5f.5 |

---

## 6b.4 Composition rules

1. **No feature widget references a primitive token** (§6.1), enforced by lint.
2. **No component owns its data.** Presentation components take value objects; state comes from Riverpod
   providers in the feature layer. This is what makes widget tests trivial and the mock layer sufficient.
3. **Every list item that is tappable is one merged semantic node.** Fragmented card semantics are the
   most common accessibility failure in commerce apps.
4. **Every component with a loading state defers its indicator by 400 ms** — inside the component.
5. **No component hardcodes a string.** All copy via ARB (§C8).
6. **Money is rendered, never computed** (R1) — no component performs arithmetic on `Money`.

---

## 6b.5 Phase 9 gates

Per component: golden tests in light and dark · `textScaleFactor` 1.0 and 2.0 · reduced-motion variant ·
semantic label assertions on every interactive element · automated contrast validation of the token pairs
it consumes (§6.2.8).
