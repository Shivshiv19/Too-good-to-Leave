# Phase 5f — Screen Definitions: Account

Status: for approval · Conventions: [05-index](05-screen-definitions-index.md) · Routes: [Phase 4 §4.2](04-navigation-flow.md)

**Surface reconciliation.** Phase 2 §2.4 enumerated 12 items for this area and totalled them as 11 —
an arithmetic slip in that document. They resolve to **11 screens plus 1 dialog** (Logout).

> Amendments: **A18** (§5f.1) · **A19** (§5f.9) · **A20** (§5f.11).

---

## 5f.1 Account root — `/account`

**Purpose.** Identity and navigation hub.

**Components.** Profile header (avatar with initials fallback · name · masked phone) · grouped menu ·
app version and build.

| Group | Items |
|---|---|
| Account | Edit profile · Saved locations |
| Preferences | Notification settings · App settings |
| Support | Help & support · Contact us |
| About | Legal · About |
| — | Log out · Delete account |

App version and build are shown because they are the first thing support will ask for.

**States.** `authenticated` · `anonymous` · `loading` · `error`.

**Accessibility.** Menu is a semantic list with group headings. The masked phone reads correctly.
**Auth-gated items announce their gated state** — *"Edit profile, sign in required"* — rather than
appearing available and then bouncing the user to an OTP screen.

### Amendment A18 — the Account tab root is public

**Finding.** §4.3 classified all of `/account/*` as auth-required, with exceptions carved out for
legal, about, and help. But the **tab root itself** was left in the protected class, which means an
anonymous user tapping the Account tab hits the auth wall.

That is wrong under A4. An anonymous user browsing bags has entirely legitimate reasons to open this
tab: switch to dark mode, read the privacy policy before deciding to sign up, or find out how the
product works. Demanding an OTP for any of those is friction with no security purpose — none of that
content is personal.

**Change.** `/account` moves to **public**. When anonymous:

- The profile header becomes a **Sign in** prompt explaining what an account unlocks.
- Public items (App settings, Help & support, Legal, About) are fully functional.
- Auth-gated items remain **visible and labelled as such**; tapping one triggers the wall with
  `redirect` back to that item.

Showing gated items rather than hiding them is deliberate — a menu that changes shape after login
leaves users unsure what the app can do.

---

## 5f.2 Edit profile — `/account/profile`

**Components.** Avatar (upload / remove) · name · email (optional, *for receipts*) · phone
(**read-only**).

**Phone is read-only in V1.** Changing the number is an identity change that affects order history and
the auth credential itself; a self-serve flow needs OTP verification on both old and new numbers plus
account-takeover protection. Deferred deliberately, with a route to Contact us.

**States.** `idle` · `dirty` · `uploadingAvatar` · `submitting` · `submitted` · `error`.

**Error states.** Avatar upload fails → **save the rest of the form** and retry the image separately. A
failed photo upload must not discard a name edit.

**Validation.** Name per §5a.8 (Unicode letters permitted) · email ≤ 254 characters, standard format,
optional · avatar ≤ 5 MB, JPEG/PNG/WebP, **EXIF stripped before upload** (same rule as §5d.6), centre-
cropped to square.

**Accessibility.** Unsaved-changes guard on back, announced. Avatar has a label and a distinct remove
action. **Email is marked optional in its label**, not only by a visual cue.

---

## 5f.3 Saved locations — `/account/locations`

**Purpose.** Manage **discovery anchors** — not delivery addresses (§2.7.1). The copy must reflect
that, or users will expect delivery.

**Components.** List (label · address · default marker) · Add new → §5a.4 flow · edit · delete · set
default.

**States.** `loading` · `loaded` · `empty` · `editing` · `deleting` · `error`.

**Empty states.** *"Save places you search from"* + Add.

**Error states.** Delete fails → optimistic rollback. **Deleting the default promotes another or clears
it explicitly** — a dangling default reference would break the §5b.6 location switcher.

**Validation.** Label required, ≤ 30 characters · duplicate labels warn but do not block · maximum 10
saved locations.

**Accessibility.** Default state announced (*"Home, default"*). **Delete is an explicit labelled action
with confirmation, never swipe-only** (§5e.2 rationale).

---

## 5f.4 Notification settings — `/account/notifications`

**Purpose.** Give the user real control over discovery notifications while keeping transactional alerts
intact (§2.6 constraint 4, §3.5 obligation 2).

**Components.**

| Region | Contents |
|---|---|
| **OS permission banner** | Shown first when system permission is denied: *"Notifications are off in system settings"* + deep link |
| **Order updates** — always on | Order confirmed · payment issues · merchant cancellations · refund updates · **pickup reminders** |
| **Discovery** — togglable | New bags nearby · watched merchant listed |
| **Other** — togglable | Rate your pickup |

The OS banner comes first because in-app toggles are meaningless while system permission is denied —
presenting them as effective would be a lie the user acts on.

**On always-on transactional alerts.** These stay on because the user has prepaid and can lose money by
missing one; §3.5 obligation 2 requires the closing-soon alert to be unmutable by a marketing opt-out.
The honest counterpoint is that some users legitimately want silence — and they have it: **system
notification settings remain a complete escape hatch.** We simply decline to ship the footgun in-app,
and we explain why rather than hiding the reasoning.

**States.** `loading` · `loaded` · `saving` (optimistic) · `permissionDenied` · `error`.

**Error states.** Save fails → rollback with a message (§2.5).

**Accessibility.** **Always-on rows must not render as greyed-out switches** — a disabled toggle reads
as a bug and invites repeated tapping. They use a distinct visual and semantic treatment, announced as
*"Pickup reminders, always on"*, with the reason available as text.

**V1 scope.** Push only. No SMS or email preference surface, because we send no SMS or email marketing.

---

## 5f.5 App settings — `/account/settings`

**Components.** Theme (System / Light / Dark) · **Clear cache** with current size · **Data saver**
(lower-quality images).

**Clear cache with a visible size** is not filler. Storage pressure is a genuine constraint on the
mid-tier Android devices in our target market (Phase 1 §3.6), and users on those devices actively hunt
for reclaimable space. It must **never** clear auth tokens or cached order history — those are not
cache.

**Data saver** is similarly market-specific: metered connections are common, and image bandwidth is our
largest data cost to the user.

**The language row is hidden while only one locale ships.** A picker with a single option is friction
that implies missing functionality. The i18n scaffolding and the row are both built (assumption A12);
the row appears when a second locale lands.

**States.** `loaded` · `applying` · `clearingCache`.

**Error states.** Cache clear fails → message; non-critical, never blocking.

**Accessibility.** Theme options are radio semantics with the current value announced. Cache size is
announced. Data saver states its effect in text, not by inference. **Theme changes apply immediately
without a restart and without a flash** — Phase 6 must support this.

---

## 5f.6 Help & support — `/account/help`

**Components.** FAQ search · topic categories (Reservations · Pickup · Payments & refunds · Account ·
**Food safety**) · **How it works** (the re-reachable §5a.2 onboarding) · **order-scoped help**
shortcut → §5d.6 · Contact us.

The order-scoped shortcut matters: most help-seeking is about a *specific* order, and routing that
traffic into §5d.6's structured issue flow rather than a free-text ticket is what makes self-serve
resolution possible (Phase 1 risk 3).

**FAQ content is server-driven** so support answers can be corrected without an app release, with a
bundled fallback set.

**States.** `loading` · `loaded` · `stale` · `offline` · `error`.

**Error states.** Fetch fails → cached topics. **No cache → Contact us is surfaced as the primary
path.** A help screen is the single worst screen in the app to dead-end on.

**Accessibility.** Search labelled; categories as a list with headings.

---

## 5f.7 FAQ topic — `/account/help/:topicId`

**Components.** Title · body · *Was this helpful?* · related topics · Contact us.

**States.** `loading` · `loaded` · `notFound` · `error`.

**Validation / security.** Server-supplied content is rendered through a **restricted markdown subset —
never arbitrary HTML.** Rendering unconstrained remote markup in an authenticated app context is an
injection vector, and "it's our own CMS" is not a security boundary.

**Accessibility.** Heading structure preserved from content so heading navigation works. Links announce
their destination, and external links announce that they leave the app.

---

## 5f.8 Contact us — `/account/contact`

**Components.** Channels (in-app form · **WhatsApp** · email · phone with staffed hours) · **stated
response SLA** · **grievance officer details** · form (category · message · optional order reference ·
attachments).

WhatsApp is listed first among live channels because it is the dominant support expectation in this
market.

**Grievance officer details — name, designation, email, phone, address — are legally mandated** by the
Consumer Protection (E-commerce) Rules 2020, together with a published redressal timeline. They appear
here and in §5f.9, and both must be populated from one source (A19).

**States.** `idle` · `submitting` · `submitted` · `error`.

**Validation.** Category required · message ≥ 20 characters · order reference optional, validated
against the user's own orders.

**Error states.** Submit fails → input retained, retry offered, **and the alternate channels
re-surfaced** so a failing form is not the end of the road.

**Accessibility.** SLA in text. Channel actions state what they open, including that WhatsApp and phone
leave the app.

---

## 5f.9 Legal — `/account/legal/:docId`

`docId` ∈ `terms` · `privacy` · `refunds-cancellations` · `grievance`.

**Components.** Rendered document · version · **effective date** · last-updated.

**Public route** (§4.3) — a prospective user must be able to read the terms *before* creating an
account.

**Content requirements.**

| Document | Must cover |
|---|---|
| Refunds & cancellations | **The A15 cutoff · the §3.5 no-show term · the 3–7 working day refund window** |
| Privacy | Location data · device identifiers · payment tokenisation · EXIF stripping · **retention periods** · the §5f.11 deletion flow |
| Grievance | Officer identity and contact · redressal timeline |

**States.** `loading` · `loaded` · `stale` · `offline` (must be readable offline once cached) ·
`notFound` · `error`.

**Validation.** Restricted markdown subset, as §5f.7.

**Accessibility.** Correct heading hierarchy — for long legal documents, heading navigation is the
primary screen-reader affordance and its absence makes the document effectively unreadable. Must
survive `textScaleFactor` 2.0.

### Amendment A19 — policy values have a single source

**Finding.** The A15 cancellation cutoff and the §3.5 no-show term now appear in **three** places: the
checkout terms block (§5c.2), the cancel dialog (§5d.5), and the refunds policy document (here). Three
independently authored copies of a commercial term will diverge, and when they do, the version most
favourable to the customer is the one that governs — while the version we actually enforce becomes an
unfair-terms exposure.

**Change.** Policy values — cancellation cutoff, no-show terms, refund SLA, grievance SLA — live in
**server configuration** and are referenced by every surface that displays them, including the generated
legal documents. No policy number is hardcoded in the app or typed twice into a CMS.

**Phase 7 effect.** A policy-values block on the config endpoint, with the legal documents rendered
against the same values.

---

## 5f.10 About — `/account/about`

**Components.** App version and build · what the product is and why · **open-source licence
attributions** · social links · Rate this app.

The OSS attribution screen is a genuine licensing obligation under the terms of the libraries we
depend on, and it is one of the most commonly omitted screens in shipped apps. Generated at build time
from the dependency tree, not maintained by hand.

**States.** `loaded`.

**Accessibility.** Version string announced in a readable form. Licence text navigable by heading.

---

## 5f.11 Delete account — `/account/delete`

The screen with the most substance in this area, because deletion collides with obligations that cannot
be waived.

**Purpose.** Honour the user's deletion request while stating honestly what can and cannot be erased.

**Components.**

| Region | Contents |
|---|---|
| **What is deleted vs. retained** | Itemised, plain language |
| **Blockers** | Active orders · pending refunds, each with a link to resolve |
| Reason | Optional picker |
| **Confirmation** | **OTP re-verification** |
| Consequence | Order history becomes inaccessible · saved data lost · 30-day reactivation window |

**Blockers are non-negotiable.** An account cannot be deleted while a prepaid reservation is live — a
merchant is holding a bag and money is in flight — or while a refund is owed. Both are stated with a
route to resolution, not as a flat refusal.

**Confirmation is by OTP, not by typing a magic word.** Re-verification proves possession of the
number, which is what actually protects a user whose unlocked phone is in someone else's hands. Typing
`DELETE` proves only literacy.

**States.** `checkingBlockers` · `eligible` · `blocked` · `confirming` · `verifying` · `submitting` ·
`deleted` · `error`.

**Error states.** Failure leaves the account **fully intact** — no partial deletion state — with a clear
message.

**Validation.** No active orders · no pending refunds · OTP verified.

**Accessibility.** The retained-data explanation appears in the semantic tree **before** the confirm
action, so a screen-reader user cannot reach the button without encountering it. The destructive button
is labelled with its effect — *"Delete my account permanently"* — never *"Confirm"*. Blockers are
announced on entry.

### Amendment A20 — deletion is anonymise-and-retain, with a grace period

**Finding.** "Delete my account" cannot mean "erase everything" for a business that takes payments in
India. Financial and tax records carry statutory retention obligations, so a promise of total erasure
would be one we break the moment we make it.

**Change.** Deletion is defined as:

1. **Erased** — name, email, avatar, phone as an identifier, saved locations, saved merchants and
   watches, notification tokens, reviews (or reviews anonymised, per §5f note below).
2. **Retained, de-identified** — order and payment records, invoices, and tax documents, held for the
   statutory period and severed from the personal identity. **The exact period is stated in the privacy
   policy**, set by counsel rather than asserted here.
3. **30-day soft-delete grace period** — signing in within 30 days reactivates the account. Disclosed
   explicitly, not silent. This materially reduces support load from regretted deletions and is
   standard practice.
4. After 30 days the erasure step executes irreversibly.

**On reviews:** anonymised rather than removed. Deleting them would retroactively alter merchant ratings
that other users' decisions relied on. Anonymisation preserves the integrity of the trust signal
without retaining the author's identity.

**Phase 7 effect.** A deletion endpoint returning blocker state, a reactivation path on sign-in, and a
defined retention contract.

---

## 5f.12 Log out — dialog, no route

**Components.** Confirmation · **reassurance that active orders are unaffected** (the §5a.11 anxiety —
a user with a prepaid reservation reads any sign-out as *"my order is gone"*).

**Behaviour.** **Logout clears all local user data, including cached order history.** Shared and family
devices are common in this market; leaving a previous user's order history, addresses, and merchant
list readable after sign-out is a privacy failure, and one that would be discovered by the person
harmed rather than by us.

**States.** `idle` · `submitting`.

**Accessibility.** The consequence is announced before the buttons; the confirming button states the
action.

---

## Handed to Phase 6

New design-system requirements: **grouped settings list** with section headings and gated-item
treatment · **always-on preference row** (visually and semantically distinct from a disabled toggle) ·
**permission-state banner** · **long-form document renderer** (restricted markdown, heading navigation,
scales to 2.0) · **blocker list** treatment · **destructive confirmation** with effect-bearing labels
(shared with §5d.5) · **profile header** with anonymous variant · **storage/size display**.

---

# Phase 5 complete

| Area | Screens defined | Amendments raised |
|---|---|---|
| 05a Onboarding & Auth | 11 | A7 |
| 05b Discovery | 12 | A8, A9, A10 |
| 05c Reserve & Pay | 9 | A11, A12, A13 |
| 05d Orders & Pickup | 5 + 1 dialog | A14, A15, A16 |
| 05e Engagement | 3 | A17 |
| 05f Account | 11 + 1 dialog | A18, A19, A20 |
| **Total** | **51 screens + 2 dialogs** | **A7–A20** |

Phase 2 estimated ≈48 destinations. The net figure rose to 51 through the A10 empty-state split (+2)
and the A5/Phase 4 checkout additions (+2), and fell through the A17 watchlist merge (−1) and the
Active/Past and Saved consolidations.

**Open commercial decision carried forward: A15** (cancellation cutoff) needs sign-off before it
propagates into Phase 7 contracts and the legal documents.
